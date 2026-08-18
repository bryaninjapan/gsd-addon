"""
執行上下文管理 — 工作流運行時狀態、變數、輸出
"""

from dataclasses import dataclass, field
from typing import Dict, Any, List, Optional
from datetime import datetime
import json


@dataclass
class StepResult:
    """單一步驟的執行結果"""
    name: str
    tool: str
    status: str  # success, failed, skipped
    output: Any = None
    error: Optional[str] = None
    duration_ms: int = 0
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())


@dataclass
class JobResult:
    """單一 job 的執行結果"""
    name: str
    status: str  # success, failed, skipped
    steps: List[StepResult] = field(default_factory=list)
    duration_ms: int = 0
    start_time: str = field(default_factory=lambda: datetime.now().isoformat())


class WorkflowContext:
    """工作流執行上下文 — 管理變數、環境、輸出、狀態"""

    def __init__(self, workflow_config: Dict[str, Any], env_name: str = "local"):
        """
        初始化上下文

        Args:
            workflow_config: workflow.yml 的配置字典
            env_name: 環境名稱 (local, staging, production)
        """
        self.workflow_config = workflow_config
        self.env_name = env_name

        # 變數和環境
        self.variables = workflow_config.get('variables', {})
        self.env = workflow_config.get('env', {})
        self.environment_config: Dict[str, Any] = {}  # 從 environments.yaml 載入

        # 執行狀態
        self.outputs: Dict[str, Any] = {}  # step outputs
        self.job_results: Dict[str, JobResult] = {}
        self.current_job: Optional[str] = None
        self.current_step_index: int = 0

        # 特殊狀態（給工具用）
        self.server_id: Optional[str] = None
        self.tab_id: Optional[str] = None
        self.temp_files: List[str] = []

        # 失敗追蹤
        self.failures: List[Dict[str, Any]] = []
        self.should_stop = False

    def load_environment(self, env_config: Dict[str, Any]):
        """從 environments.yaml 載入環境配置"""
        if self.env_name in env_config:
            self.environment_config = env_config[self.env_name]
        else:
            raise ValueError(f"Environment '{self.env_name}' not found in environments.yaml")

    def interpolate(self, text: str) -> str:
        """
        字符串插值
        支持: ${{ variables.xxx }}, ${{ env.yyy }}, ${{ outputs.zzz }}
        """
        if not isinstance(text, str):
            return text

        # 替換 ${{ variables.* }}
        for var_name, var_value in self.variables.items():
            placeholder = f"${{{{ variables.{var_name} }}}}"
            text = text.replace(placeholder, str(var_value))

        # 替換 ${{ env.* }}
        for env_name, env_value in self.env.items():
            placeholder = f"${{{{ env.{env_name} }}}}"
            text = text.replace(placeholder, str(env_value))

        # 替換 ${{ environment.* }}
        for env_key, env_value in self.environment_config.items():
            placeholder = f"${{{{ environment.{env_key} }}}}"
            text = text.replace(placeholder, str(env_value))

        # 替換 ${{ outputs.* }}
        for output_key, output_value in self.outputs.items():
            # 支持嵌套: outputs.start_server.outputs.serverId
            if '.' in output_key:
                placeholder = f"${{{{ outputs.{output_key} }}}}"
                if isinstance(output_value, dict) and 'outputs' in output_value:
                    for nested_key, nested_value in output_value['outputs'].items():
                        nested_placeholder = f"${{{{ outputs.{output_key}.outputs.{nested_key} }}}}"
                        text = text.replace(nested_placeholder, str(nested_value))

        return text

    def save_step_result(self, step_result: StepResult):
        """保存步驟結果"""
        if self.current_job:
            if self.current_job not in self.job_results:
                self.job_results[self.current_job] = JobResult(
                    name=self.current_job,
                    status="running"
                )
            self.job_results[self.current_job].steps.append(step_result)

    def save_output(self, step_id: str, output: Any):
        """保存步驟輸出"""
        self.outputs[step_id] = output

    def record_failure(self, step_name: str, error: str, step_id: Optional[str] = None):
        """記錄失敗"""
        self.failures.append({
            'step': step_name,
            'step_id': step_id,
            'error': error,
            'timestamp': datetime.now().isoformat(),
            'job': self.current_job
        })

    def to_dict(self) -> Dict[str, Any]:
        """序列化為字典（用於 JSON 輸出）"""
        return {
            'env_name': self.env_name,
            'variables': self.variables,
            'outputs': self.outputs,
            'job_results': {
                name: {
                    'name': result.name,
                    'status': result.status,
                    'steps': [
                        {
                            'name': s.name,
                            'tool': s.tool,
                            'status': s.status,
                            'duration_ms': s.duration_ms
                        }
                        for s in result.steps
                    ]
                }
                for name, result in self.job_results.items()
            },
            'failures': self.failures
        }

    def to_json(self) -> str:
        """序列化為 JSON"""
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)

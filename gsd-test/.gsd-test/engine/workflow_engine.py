"""
核心 Workflow 執行引擎 — 解析和執行 workflow.yml
"""

import yaml
import sys
from typing import Dict, Any, List, Optional
from datetime import datetime
import time

from context import WorkflowContext, StepResult, JobResult
from tools import ToolRegistry, ToolResult


class WorkflowEngine:
    """工作流執行引擎"""

    def __init__(self, workflow_path: str, env_name: str = "local", environments_path: Optional[str] = None):
        """
        初始化引擎

        Args:
            workflow_path: workflow.yml 檔案路徑
            env_name: 環境名稱
            environments_path: environments.yaml 檔案路徑
        """
        self.workflow_path = workflow_path
        self.env_name = env_name

        # 載入 workflow
        with open(workflow_path, 'r', encoding='utf-8') as f:
            self.workflow_config = yaml.safe_load(f)

        # 載入環境配置
        self.environments_config = {}
        if environments_path:
            with open(environments_path, 'r', encoding='utf-8') as f:
                self.environments_config = yaml.safe_load(f).get('environments', {})

        # 初始化上下文和工具
        self.context = WorkflowContext(self.workflow_config, env_name)
        if self.environments_config:
            self.context.load_environment(self.environments_config)

        self.tool_registry = ToolRegistry()

        # 執行統計
        self.total_steps = 0
        self.passed_steps = 0
        self.failed_steps = 0

    def execute(self) -> bool:
        """執行整個 workflow，返回是否成功"""
        print(f"\n{'='*60}")
        print(f"🚀 Workflow: {self.workflow_config.get('name', 'Unknown')}")
        print(f"📍 Environment: {self.env_name}")
        print(f"{'='*60}\n")

        jobs = self.workflow_config.get('jobs', {})
        job_names = list(jobs.keys())

        # 執行每個 job
        for job_name in job_names:
            job = jobs[job_name]

            # 檢查 job 依賴
            if not self._check_job_dependencies(job_name, jobs):
                print(f"⏭️  Skipping job '{job_name}' (dependency failed)")
                continue

            # 檢查 if 條件
            if 'if' in job and not self._evaluate_condition(job['if']):
                print(f"⏭️  Skipping job '{job_name}' (if condition false)")
                continue

            print(f"\n🔵 Job: {job_name}")
            print(f"   {job.get('name', job_name)}")

            success = self._execute_job(job_name, job)

            if not success and not job.get('continue_on_error', False):
                print(f"\n❌ Workflow failed at job '{job_name}'")
                return False

        # 最終報告
        self._print_summary()

        return self.failed_steps == 0

    def _execute_job(self, job_name: str, job: Dict[str, Any]) -> bool:
        """執行單一 job"""
        self.context.current_job = job_name

        # 初始化 job 結果
        job_result = JobResult(
            name=job_name,
            status="running"
        )
        self.context.job_results[job_name] = job_result

        steps = job.get('steps', [])
        job_success = True

        for step_idx, step in enumerate(steps):
            self.context.current_step_index = step_idx

            # 檢查 if 條件
            if 'if' in step and not self._evaluate_condition(step['if']):
                print(f"   ⏭️  Skipped: {step.get('name', f'step-{step_idx}')}")
                continue

            success = self._execute_step(step)
            self.total_steps += 1

            if success:
                self.passed_steps += 1
            else:
                self.failed_steps += 1
                job_success = False

                # 檢查是否應該停止或繼續
                if step.get('on_failure') == 'stop':
                    break
                elif step.get('on_failure') == 'retry':
                    retry_count = step.get('retry_count', 3)
                    for attempt in range(1, retry_count + 1):
                        print(f"      🔄 Retry {attempt}/{retry_count}")
                        success = self._execute_step(step)
                        if success:
                            self.passed_steps += 1
                            self.failed_steps -= 1
                            job_success = True
                            break

        job_result.status = "success" if job_success else "failed"
        return job_success

    def _execute_step(self, step: Dict[str, Any]) -> bool:
        """執行單一步驟"""
        step_name = step.get('name', 'unknown')
        tool_name = step.get('tool', 'bash')
        step_id = step.get('id')

        print(f"   → {step_name}")

        start_time = time.time()

        # 獲取並插值參數
        params = self._interpolate_params(step.get('params', {}))

        # 執行工具
        tool_result = self.tool_registry.call(tool_name, params)

        duration_ms = int((time.time() - start_time) * 1000)

        # 保存結果
        step_result = StepResult(
            name=step_name,
            tool=tool_name,
            status="success" if tool_result.success else "failed",
            output=tool_result.output,
            error=tool_result.error,
            duration_ms=duration_ms
        )

        self.context.save_step_result(step_result)

        if tool_result.success:
            # 保存輸出（如果有 id）
            if step_id:
                self.context.save_output(step_id, tool_result.output)

            # 執行斷言
            if 'assertions' in step:
                assertions_passed = self._check_assertions(step['assertions'], tool_result.output)
                if not assertions_passed:
                    print(f"      ✗ Assertion failed")
                    self.context.record_failure(step_name, "Assertion failed", step_id)
                    return False

            print(f"      ✓ Success ({duration_ms}ms)")
            return True
        else:
            print(f"      ✗ Failed: {tool_result.error}")
            self.context.record_failure(step_name, tool_result.error or "Unknown error", step_id)

            # 執行 on_error 動作
            if 'on_error' in step:
                self._handle_step_error(step['on_error'])

            return False

    def _interpolate_params(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """插值參數"""
        result = {}

        for key, value in params.items():
            if isinstance(value, str):
                result[key] = self.context.interpolate(value)
            elif isinstance(value, dict):
                result[key] = self._interpolate_params(value)
            elif isinstance(value, list):
                result[key] = [
                    self.context.interpolate(v) if isinstance(v, str) else v
                    for v in value
                ]
            else:
                result[key] = value

        return result

    def _check_assertions(self, assertions: List[Dict[str, Any]], actual: Any) -> bool:
        """檢查斷言"""
        for assertion in assertions:
            if isinstance(assertion, str):
                # 簡單形式: "contains: xxx"
                if 'contains' in assertion:
                    expected = assertion.split(':', 1)[1].strip()
                    if expected not in str(actual):
                        return False
            elif isinstance(assertion, dict):
                # 複雜形式: {must_contain: "xxx"}
                if 'must_contain' in assertion:
                    if assertion['must_contain'] not in str(actual):
                        return False
                if 'must_equal' in assertion:
                    if str(actual) != str(assertion['must_equal']):
                        return False

        return True

    def _evaluate_condition(self, condition: str) -> bool:
        """
        評估條件
        支持: always, never, 或簡單的表達式
        """
        if condition == "always" or condition is True:
            return True
        if condition == "never" or condition is False:
            return False

        # 評估為 Python 表達式
        try:
            # 注入上下文變數
            eval_context = {
                'variables': self.context.variables,
                'env': self.context.env,
                'environment': self.context.environment_config
            }
            return bool(eval(condition, {"__builtins__": {}}, eval_context))
        except:
            return False

    def _check_job_dependencies(self, job_name: str, all_jobs: Dict[str, Any]) -> bool:
        """檢查 job 依賴是否滿足"""
        job = all_jobs[job_name]
        dependencies = job.get('needs', [])

        if not dependencies:
            return True

        # 檢查所有依賴是否成功
        for dep_name in dependencies:
            if dep_name in self.context.job_results:
                if self.context.job_results[dep_name].status != "success":
                    return False

        return True

    def _handle_step_error(self, error_actions: Any):
        """處理步驟錯誤"""
        if isinstance(error_actions, str):
            if error_actions.startswith('retry('):
                # 由調用方處理重試
                pass
        elif isinstance(error_actions, list):
            for action in error_actions:
                if isinstance(action, dict):
                    action_name = action.get('action')
                    if action_name == 'log_error':
                        print(f"      [Error logged]")

    def _print_summary(self):
        """打印執行摘要"""
        print(f"\n{'='*60}")
        print(f"📊 Summary")
        print(f"{'='*60}")
        print(f"Total steps: {self.total_steps}")
        print(f"Passed:      {self.passed_steps} ✓")
        print(f"Failed:      {self.failed_steps} ✗")

        if self.context.failures:
            print(f"\nFailures:")
            for failure in self.context.failures:
                print(f"  - {failure['step']}: {failure['error']}")

        print(f"\n{'='*60}\n")

        # 返回狀態碼
        return 0 if self.failed_steps == 0 else 1

    def get_results(self) -> Dict[str, Any]:
        """獲取執行結果"""
        return self.context.to_dict()

    def save_results(self, output_path: str):
        """保存執行結果為 JSON"""
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(self.context.to_json())
        print(f"\n💾 Results saved to {output_path}")

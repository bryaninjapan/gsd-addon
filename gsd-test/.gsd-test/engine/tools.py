"""
工具適配層 — 適配 Claude Code 內置工具 + Bash + 自定義工具
"""

import subprocess
import json
import re
import time
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass


@dataclass
class ToolResult:
    """工具執行結果"""
    success: bool
    output: Any = None
    error: Optional[str] = None
    metadata: Dict[str, Any] = None

    def to_dict(self):
        return {
            'success': self.success,
            'output': self.output,
            'error': self.error,
            'metadata': self.metadata or {}
        }


class ToolRegistry:
    """工具註冊表 — 管理所有可用工具"""

    def __init__(self):
        self.tools: Dict[str, Callable] = {}
        self._register_builtin_tools()

    def _register_builtin_tools(self):
        """註冊內置工具"""
        self.register('bash', self._tool_bash)
        self.register('preview_start', self._tool_preview_start)
        self.register('preview_stop', self._tool_preview_stop)
        self.register('preview_logs', self._tool_preview_logs)
        self.register('read_page', self._tool_read_page)
        self.register('read_network_requests', self._tool_read_network_requests)
        self.register('form_input', self._tool_form_input)
        self.register('computer', self._tool_computer)
        self.register('wait', self._tool_wait)
        self.register('file_write', self._tool_file_write)
        self.register('file_read', self._tool_file_read)
        self.register('assert', self._tool_assert)

    def register(self, name: str, func: Callable):
        """註冊工具"""
        self.tools[name] = func

    def call(self, tool_name: str, params: Dict[str, Any]) -> ToolResult:
        """調用工具"""
        if tool_name not in self.tools:
            return ToolResult(
                success=False,
                error=f"Tool '{tool_name}' not found. Available: {list(self.tools.keys())}"
            )

        try:
            result = self.tools[tool_name](params)
            return result
        except Exception as e:
            return ToolResult(success=False, error=str(e))

    # ==================== 工具實現 ====================

    def _tool_bash(self, params: Dict[str, Any]) -> ToolResult:
        """執行 bash 命令"""
        command = params.get('command', '')
        timeout = params.get('timeout', 30)

        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=timeout
            )

            return ToolResult(
                success=result.returncode == 0,
                output={
                    'stdout': result.stdout,
                    'stderr': result.stderr,
                    'returncode': result.returncode
                }
            )
        except subprocess.TimeoutExpired:
            return ToolResult(success=False, error=f"Command timeout after {timeout}s")

    def _tool_preview_start(self, params: Dict[str, Any]) -> ToolResult:
        """
        啟動開發服務器
        實際上這會呼叫 Claude Code 的 preview_start
        這裡只返回模擬結果
        """
        name = params.get('name', 'dev')
        # 實際使用時，這會通過 Claude Code API 呼叫
        # 這裡為了演示目的返回模擬結果

        return ToolResult(
            success=True,
            output={
                'serverId': f'server-{name}-{int(time.time())}',
                'tabId': f'tab-{name}',
                'port': params.get('port', 8788)
            }
        )

    def _tool_preview_stop(self, params: Dict[str, Any]) -> ToolResult:
        """停止開發服務器"""
        server_id = params.get('serverId')
        return ToolResult(
            success=True,
            output={'stopped': server_id}
        )

    def _tool_preview_logs(self, params: Dict[str, Any]) -> ToolResult:
        """獲取服務器日誌"""
        server_id = params.get('serverId')
        lines = params.get('lines', 50)

        # 模擬返回日誌
        return ToolResult(
            success=True,
            output={
                'logs': f'[Mock logs for {server_id}]',
                'line_count': lines
            }
        )

    def _tool_read_page(self, params: Dict[str, Any]) -> ToolResult:
        """讀取頁面結構"""
        tab_id = params.get('tabId', 'tab-1')

        # 實際使用時會呼叫 Claude Code 的 read_page
        return ToolResult(
            success=True,
            output={
                'page_structure': '[Mock page content]',
                'references': []
            }
        )

    def _tool_read_network_requests(self, params: Dict[str, Any]) -> ToolResult:
        """讀取網路請求"""
        tab_id = params.get('tabId', 'tab-1')
        limit = params.get('limit', 10)

        return ToolResult(
            success=True,
            output={
                'requests': [
                    {'url': 'http://localhost:8788/api/services', 'status': 200}
                ],
                'count': 1
            }
        )

    def _tool_form_input(self, params: Dict[str, Any]) -> ToolResult:
        """填表單"""
        fields = params.get('fields', [])

        # 支持單個字段或多個字段
        if 'ref' in params:
            fields = [{'ref': params['ref'], 'value': params['value']}]

        return ToolResult(
            success=True,
            output={
                'filled_fields': len(fields),
                'fields': fields
            }
        )

    def _tool_computer(self, params: Dict[str, Any]) -> ToolResult:
        """滑鼠/鍵盤操作"""
        action = params.get('action')
        ref = params.get('ref')

        return ToolResult(
            success=True,
            output={
                'action': action,
                'ref': ref,
                'executed': True
            }
        )

    def _tool_wait(self, params: Dict[str, Any]) -> ToolResult:
        """等待"""
        duration = params.get('duration', 1)
        time.sleep(duration)

        return ToolResult(
            success=True,
            output={'waited_seconds': duration}
        )

    def _tool_file_write(self, params: Dict[str, Any]) -> ToolResult:
        """寫檔案"""
        path = params.get('path')
        content = params.get('content')

        try:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            return ToolResult(success=True, output={'path': path})
        except Exception as e:
            return ToolResult(success=False, error=str(e))

    def _tool_file_read(self, params: Dict[str, Any]) -> ToolResult:
        """讀檔案"""
        path = params.get('path')

        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            return ToolResult(success=True, output={'content': content})
        except Exception as e:
            return ToolResult(success=False, error=str(e))

    def _tool_assert(self, params: Dict[str, Any]) -> ToolResult:
        """
        斷言 — 驗證條件
        支持:
          - contains: "text"
          - equals: "value"
          - matches: "regex"
        """
        actual = params.get('actual')
        assertions = params.get('assertions', {})

        results = []

        for assertion_type, expected_value in assertions.items():
            if assertion_type == 'contains':
                passed = expected_value in str(actual)
                results.append({
                    'type': 'contains',
                    'expected': expected_value,
                    'passed': passed
                })
            elif assertion_type == 'equals':
                passed = str(actual) == str(expected_value)
                results.append({
                    'type': 'equals',
                    'expected': expected_value,
                    'passed': passed
                })
            elif assertion_type == 'matches':
                passed = bool(re.search(expected_value, str(actual)))
                results.append({
                    'type': 'matches',
                    'pattern': expected_value,
                    'passed': passed
                })

        all_passed = all(r['passed'] for r in results)

        return ToolResult(
            success=all_passed,
            output={
                'assertions': results,
                'all_passed': all_passed
            }
        )

#!/usr/bin/env python3
"""
CLI 工具 — 命令行界面用於執行 workflow
"""

import argparse
import sys
import os
from pathlib import Path

# 添加引擎路徑
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'engine'))

from workflow_engine import WorkflowEngine


def main():
    parser = argparse.ArgumentParser(
        description='Test Orchestration Engine - Run automated test workflows',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run workflow in local environment
  python cli.py --workflow workflows/booking-e2e.workflow.yml

  # Run in staging environment
  python cli.py --workflow workflows/booking-e2e.workflow.yml --env staging

  # Save results to file
  python cli.py --workflow workflows/api-smoke.workflow.yml --output results.json

  # Override environment variable
  python cli.py --workflow workflows/booking-e2e.workflow.yml --env local --var name="Custom Name"
        """
    )

    parser.add_argument(
        '--workflow', '-w',
        required=True,
        help='Path to workflow.yml file'
    )

    parser.add_argument(
        '--env', '-e',
        default='local',
        choices=['local', 'docker', 'staging', 'production'],
        help='Environment to run in (default: local)'
    )

    parser.add_argument(
        '--environments', '-E',
        default='environments/environments.yaml',
        help='Path to environments.yaml file (default: environments/environments.yaml)'
    )

    parser.add_argument(
        '--output', '-o',
        help='Save results to JSON file'
    )

    parser.add_argument(
        '--var', '-v',
        action='append',
        help='Override workflow variable (format: key=value)'
    )

    parser.add_argument(
        '--verbose', '-V',
        action='store_true',
        help='Verbose output'
    )

    args = parser.parse_args()

    # 驗證 workflow 檔案
    if not os.path.exists(args.workflow):
        print(f"❌ Workflow file not found: {args.workflow}")
        sys.exit(1)

    # 驗證環境配置檔案
    environments_path = args.environments
    if not os.path.exists(environments_path):
        print(f"⚠️  Environments file not found: {environments_path}")
        print(f"    Running without environment-specific configuration")
        environments_path = None

    # 創建引擎
    try:
        engine = WorkflowEngine(
            workflow_path=args.workflow,
            env_name=args.env,
            environments_path=environments_path
        )

        # 應用變數覆蓋
        if args.var:
            for var_def in args.var:
                if '=' in var_def:
                    key, value = var_def.split('=', 1)
                    engine.context.variables[key.strip()] = value.strip()
                    if args.verbose:
                        print(f"📝 Set variable: {key} = {value}")

        # 執行 workflow
        if args.verbose:
            print(f"📋 Workflow: {args.workflow}")
            print(f"🌍 Environment: {args.env}")

        success = engine.execute()

        # 保存結果
        if args.output:
            engine.save_results(args.output)

        # 返回狀態碼
        sys.exit(0 if success else 1)

    except Exception as e:
        print(f"❌ Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

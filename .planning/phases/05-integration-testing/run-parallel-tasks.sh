#!/usr/bin/env bash
# Parallel execution of Tasks 5.2-5.5 in soapwavehealing

set -euo pipefail

PROJECT_ROOT="/Users/bryan/Documents/soapwavehealing"
ADDON_HOME="$HOME/.claude/gsd-addon"
LOG_DIR="$ADDON_HOME/.planning/soldier-logs"

mkdir -p "$LOG_DIR"

echo "════════════════════════════════════════════════════════"
echo "  Phase 5: Parallel Tasks 5.2-5.5"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Tasks:"
echo "  5.2: Baseline test (no RETRY)"
echo "  5.3: RETRY=true functional test"
echo "  5.4: Checkpoint conflict validation"
echo "  5.5: Timeout reasonableness check"
echo ""
echo "Launching 4 parallel dispatches..."
echo ""

# Task 5.2: Baseline test (no RETRY)
(
  cd "$PROJECT_ROOT"
  unset RETRY 2>/dev/null || true
  echo "[5.2] Baseline test starting..."
  MODE=research TARGET_DIR="." gsd-dispatch 1 2>&1 | tee "/tmp/phase5-task52.log" || true
  echo "[5.2] ✓ Baseline test completed"
) &
PID_52=$!

# Task 5.3: RETRY=true functional test
(
  cd "$PROJECT_ROOT"
  export RETRY=true
  echo "[5.3] RETRY=true test starting..."
  MODE=research TARGET_DIR="." gsd-dispatch 1 2>&1 | tee "/tmp/phase5-task53.log" || true
  echo "[5.3] ✓ RETRY=true test completed"
) &
PID_53=$!

# Task 5.4: Checkpoint conflict check
(
  cd "$PROJECT_ROOT"
  echo "[5.4] Checkpoint validation starting..."

  # Check existing checkpoint files before
  BEFORE=$(find .planning -name "*.md" -type f 2>/dev/null | sort)

  # Run dispatch with RETRY
  export RETRY=true
  MODE=research TARGET_DIR="." gsd-dispatch 2 2>&1 | tee "/tmp/phase5-task54.log" || true

  # Check existing checkpoint files after
  AFTER=$(find .planning -name "*.md" -type f 2>/dev/null | sort)

  # Verify no files were deleted
  if [ "$BEFORE" = "$AFTER" ]; then
    echo "[5.4] ✓ Checkpoint files unchanged (no conflicts)"
  else
    echo "[5.4] ⚠ Checkpoint files changed (needs review)"
  fi
) &
PID_54=$!

# Task 5.5: Timeout verification
(
  cd "$PROJECT_ROOT"
  echo "[5.5] Timeout verification starting..."

  # Run dispatch and capture exit code
  export RETRY=true
  MODE=research TARGET_DIR="." gsd-dispatch 1 2>&1 | tee "/tmp/phase5-task55.log" || EXIT_CODE=$?

  # Check for timeout markers in log
  LATEST_LOG=$(ls -t "$ADDON_HOME/.planning/soldier-logs"/phase-*.log 2>/dev/null | head -1)
  if [ -n "$LATEST_LOG" ]; then
    if grep -q "exit 124\|timeout" "$LATEST_LOG" 2>/dev/null; then
      echo "[5.5] ⚠ Timeout detected (exit 124)"
    else
      echo "[5.5] ✓ No premature timeouts"
    fi
  fi
) &
PID_55=$!

echo "PID mapping:"
echo "  5.2 (baseline): $PID_52"
echo "  5.3 (RETRY):    $PID_53"
echo "  5.4 (checkpoint): $PID_54"
echo "  5.5 (timeout):  $PID_55"
echo ""
echo "Waiting for all tasks to complete..."
echo "(This may take 10-15 minutes)"
echo ""

# Wait for all background jobs
wait $PID_52 $PID_53 $PID_54 $PID_55 || true

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅ All parallel tasks completed"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Results summary:"
echo ""
echo "=== Task 5.2 (Baseline) ==="
tail -10 /tmp/phase5-task52.log 2>/dev/null || echo "No output"
echo ""
echo "=== Task 5.3 (RETRY=true) ==="
tail -10 /tmp/phase5-task53.log 2>/dev/null || echo "No output"
echo ""
echo "=== Task 5.4 (Checkpoint) ==="
tail -10 /tmp/phase5-task54.log 2>/dev/null || echo "No output"
echo ""
echo "=== Task 5.5 (Timeout) ==="
tail -10 /tmp/phase5-task55.log 2>/dev/null || echo "No output"
echo ""
echo "Next: Task 5.6 (Update DEVELOPMENT-WORKFLOW.md)"

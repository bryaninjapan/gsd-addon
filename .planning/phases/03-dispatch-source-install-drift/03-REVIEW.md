---
phase: 03-dispatch-source-install-drift
reviewed: 2026-08-19T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - scripts/gsd-dispatch.sh
  - prompts/execute.md
  - prompts/plan.md
  - prompts/research.md
  - prompts/check.md
  - prompts/revise.md
findings:
  critical: 3
  warning: 5
  info: 4
  total: 12
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-08-19T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed `gsd-dispatch.sh` (primary dispatch script backported from installed copy) and five prompt templates newly added to the source repo. The prompt templates themselves are well-structured with no injection risks in their substitution design. The dispatch script has three critical correctness bugs that affect every dispatch invocation: the script aborts without printing diagnostic output whenever `opencode` exits non-zero; the liveness check for execute mode can never find the SUMMARY file because the filename pattern is wrong (confirmed by evidence in the actual repo); and research mode liveness falls through to the wrong branch. Additionally five quality warnings were found in the script.

---

## Critical Issues

### CR-01: Script aborts before liveness/diagnostic output when opencode exits non-zero

**File:** `scripts/gsd-dispatch.sh:247-254`
**Issue:** The dispatch subshell runs under `set -euo pipefail`. If `opencode run` exits with any non-zero code — including the timeout code 124 returned by `run_with_timeout` — the pipeline at line 254 exits non-zero and `set -e` terminates the script immediately. All subsequent sections (liveness checks lines 261-268, session count check lines 270-283, git diff / new-commit output lines 290-312, output-file discovery lines 319-351, and next-steps guidance lines 353-389) are silently skipped. The operator sees log output via `tee` but receives no indication of whether the failure was a timeout, an opencode error, or something else.

**Fix:**
```bash
# Capture the dispatch exit code without letting set -e abort the script
DISPATCH_RC=0
(
  cd "$TARGET_DIR"
  run_with_timeout 3600 opencode run \
    -m "$MODEL" \
    ${VARIANT:+--variant "$VARIANT"} \
    ${SERVER_URL:+--attach "$SERVER_URL"} \
    "$FULL_PROMPT"
) 2>&1 | tee "$LOG_FILE" || DISPATCH_RC=$?

if [[ $DISPATCH_RC -ne 0 ]]; then
  [[ $DISPATCH_RC -eq 124 ]] \
    && echo "✗ TIMEOUT: opencode did not finish within 3600s (exit 124)" \
    || echo "✗ opencode exited with code $DISPATCH_RC"
fi
# Continue to liveness checks regardless
```

---

### CR-02: Execute-mode liveness check uses wrong filename pattern; never finds SUMMARY files

**File:** `scripts/gsd-dispatch.sh:345`
**Issue:** Line 345 runs `find ... -name 'SUMMARY.md'`. However, `prompts/execute.md` (line 28) instructs the agent to write the file as `{{PHASE}}-SUMMARY.md`. After substitution this produces names such as `2-SUMMARY.md` and `3-SUMMARY.md` — exactly what exists in the repo today (`.planning/phases/02-dispatch-timeout-hardening/2-SUMMARY.md`, `.planning/phases/03-dispatch-source-install-drift/3-SUMMARY.md`). A file named `2-SUMMARY.md` does **not** match `-name 'SUMMARY.md'`. The liveness check always reports "未找到" for execute mode, even after a fully successful dispatch.

**Fix:**
```bash
# At line 345, change -name 'SUMMARY.md' to match the actual naming convention:
SUMMARY="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" \
  -name "*-SUMMARY.md" 2>/dev/null | head -1)"
```

---

### CR-03: Research mode liveness check falls to else branch and looks for SUMMARY.md

**File:** `scripts/gsd-dispatch.sh:319-350`
**Issue:** The if-elif chain at lines 319-351 handles `plan`, `check`, and `revise` explicitly, then falls to `else` for all remaining modes. Both `execute` and `research` hit the `else` branch, which looks for `SUMMARY.md`. However, `prompts/research.md` (line 29) instructs the agent to produce `{{PHASE}}-RESEARCH.md`. A successful research dispatch always reports "未找到 Phase N 的 SUMMARY.md". Because research is the first step in the workflow, this false negative could cause operators to re-run dispatches unnecessarily.

**Fix:**
```bash
elif [[ "$MODE" == "research" ]]; then
  echo "── 士兵產出的 RESEARCH.md(軍師讀結論)────────────────────"
  RESEARCH_FILES="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" \
    -name "*-RESEARCH.md" 2>/dev/null | sort)"
  if [[ -n "$RESEARCH_FILES" ]]; then
    echo "$RESEARCH_FILES" | sed "s#^#找到: #; s#${PROJECT_DIR}/##"
  else
    echo "（未找到 Phase ${PHASE} 的 RESEARCH.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
else
  # execute mode only
  ...
fi
```

---

## Warnings

### WR-01: awk regex injection via unvalidated PHASE in extract_phase_section

**File:** `scripts/gsd-dispatch.sh:130`
**Issue:** `$PHASE` is passed as an awk variable and used directly in a dynamic regex: `$0 ~ "^### Phase " phase "[:.]"`. Two problems:

1. **Incorrect wildcard**: Phase values like `6.3` cause `.` to act as a regex wildcard, matching `Phase 6X3:` as well as `Phase 6.3:`. For the specific phase numbers in normal use this is unlikely to cause a wrong match, but it is semantically incorrect.

2. **awk abort on metacharacters**: If `PHASE` contains `[` (e.g., a mistyped phase argument), awk interprets the composite pattern as an unterminated bracket expression and exits with code 2. Confirmed empirically: `awk -v phase="6[" '...'` prints "awk: nonterminated character class" and exits 2. Under `set -e`, this aborts the script at line 228.

**Fix:** Escape regex metacharacters in the awk variable before use, or use exact equality comparison:
```awk
# Option A: exact match on colon variant
$0 == "### Phase " phase ":" || $0 == "### Phase " phase "." { found=1; print; next }
# Option B: escape dots via gsub before the pattern
BEGIN { gsub(/\./, "\\.", phase) }
```

---

### WR-02: Dead code — preflight_external_perms() defined but never called

**File:** `scripts/gsd-dispatch.sh:158-187`
**Issue:** `preflight_external_perms()` is a 26-line function that is explicitly never called. The comment at lines 184-187 acknowledges this ("故保留函式定義但不呼叫"). Dead code that is intentionally retained creates ongoing maintenance burden and misleads readers into thinking it might be called conditionally.

**Fix:** Remove the function body entirely (lines 158-183), or move it to a separate utility script with a comment explaining why it was preserved. At minimum the retaining-comment at 184-187 should be replaced with a `# DELETED` note if removal is appropriate.

---

### WR-03: stat -f%z is macOS-specific; silently misreports file size on Linux

**File:** `scripts/gsd-dispatch.sh:262`
**Issue:** `stat -f%z` is BSD/macOS syntax. On GNU/Linux, `stat -c%s` is required. On Linux, `stat -f%z "$LOG_FILE"` fails; the `|| echo 0` fallback makes `LOG_SIZE=0`, which unconditionally triggers the "✗ FAIL: log 檔 0 bytes" error even for a successful dispatch where the log file is non-empty. The script header for `run_with_timeout` claims "任何 bash 3.2+ 環境皆可跑" but the liveness check defeats this on non-macOS.

**Fix:**
```bash
# Portable file size: wc -c is available everywhere
LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
```

---

### WR-04: VARIANT not validated against documented whitelist

**File:** `scripts/gsd-dispatch.sh:79`
**Issue:** `VARIANT="${VARIANT:-high}"` accepts any user-supplied string without validation. The variable is documented as accepting only `high`, `max`, or `minimal`, but any value (including empty strings with shell metacharacters) is passed directly to `opencode run --variant "$VARIANT"`. Invalid VARIANT values may cause opencode to silently misbehave or error out.

**Fix:** Add a case validation parallel to the existing MODE check:
```bash
case "$VARIANT" in
  high|max|minimal) ;;
  *)
    echo "✗ VARIANT 必須是 high、max 或 minimal,得到: $VARIANT"
    exit 1
    ;;
esac
```

---

### WR-05: Theoretical PID reuse race in run_with_timeout

**File:** `scripts/gsd-dispatch.sh:59-71`
**Issue:** After the main command exits naturally, the watcher subshell `( sleep "$secs" && kill -TERM "$cmd_pid" )` may complete its `sleep` in the window between the command's exit and the `kill -TERM "$watcher_pid"` call at line 70. If the original `cmd_pid` has been released and reused by a new OS process, that process receives an unintended SIGTERM. On a heavily-loaded system this race is small but nonzero.

**Fix:** Have the watcher check whether the PID still belongs to the same process before killing, or use a coordination signal approach. A simpler partial mitigation is to send SIGTERM to the watcher's process group rather than just its PID:
```bash
( sleep "$secs" && kill -TERM "$cmd_pid" 2>/dev/null ) &
local watcher_pid=$!
# ... on success path:
kill -TERM "-$watcher_pid" 2>/dev/null   # kill watcher's process group
wait "$watcher_pid" 2>/dev/null
```
Note: this does not fully eliminate the race, but reduces the window. A fully correct solution requires a named pipe or a lock file for the watcher to check before killing.

---

## Info

### IN-01: Zero-width space (U+200B) embedded in plan.md path example

**File:** `prompts/plan.md:11`
**Issue:** A zero-width space (U+200B, bytes `\xe2\x80\x8b`) is embedded between `*/` and `*-PLAN.md` in the path pattern `.planning/phases/*/​*-PLAN.md`. The character is invisible in most editors and Markdown renderers. If an AI agent or a human operator copies this path into a shell glob or `find` command, the hidden character causes an immediate "no such file" or "invalid pattern" error.

**Fix:** Delete the zero-width space. The corrected text should read `.planning/phases/*/**-PLAN.md` with no invisible characters between the two `*`.

---

### IN-02: Duplicate "士兵執行中…" status message

**File:** `scripts/gsd-dispatch.sh:218,232`
**Issue:** The string "士兵執行中…" is printed twice — once inside the banner box at line 218 and again at line 232 outside it. Cosmetic noise in terminal output.

**Fix:** Remove one of the two occurrences. Line 218 is inside the decorative border block and is the better one to retain; remove line 232's standalone echo.

---

### IN-03: PHASE not validated for path-safe characters

**File:** `scripts/gsd-dispatch.sh:76,86`
**Issue:** `PHASE="${1:-}"` accepts arbitrary strings. If PHASE contains `/` (e.g., a mistype of `6/3` instead of `6.3`), then `LOG_FILE` at line 86 becomes `${LOG_DIR}/phase-6/3-YYYYMMDD-HHMMSS.log` — a path whose intermediate directory `${LOG_DIR}/phase-6/` does not exist. When `tee "$LOG_FILE"` attempts to open the file, it fails, and with `set -e` the script aborts with a confusing error before any dispatch work is attempted.

**Fix:** After the PHASE check at line 108, add a format guard:
```bash
if [[ ! "$PHASE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "✗ PHASE 格式不合法: $PHASE (預期 N 或 N.M,例如 7 或 6.3)"
  exit 1
fi
```

---

### IN-04: $FULL_PROMPT not guarded by -- argument separator

**File:** `scripts/gsd-dispatch.sh:253`
**Issue:** `"$FULL_PROMPT"` is the last argument to `opencode run` with no `--` separator. All current templates start with `You are acting as`, so this is harmless today. If a template is ever modified to start with a `-` character (e.g., after a future edit), `opencode run` would misinterpret the prompt as a flag. This is a latent fragility.

**Fix:**
```bash
run_with_timeout 3600 opencode run \
  -m "$MODEL" \
  ${VARIANT:+--variant "$VARIANT"} \
  ${SERVER_URL:+--attach "$SERVER_URL"} \
  -- \
  "$FULL_PROMPT"
```
(Requires verifying that `opencode run` accepts `--` as an argument separator — check the opencode CLI docs if uncertain.)

---

_Reviewed: 2026-08-19T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

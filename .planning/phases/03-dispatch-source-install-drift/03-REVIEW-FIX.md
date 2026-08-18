---
phase: 03-dispatch-source-install-drift
fixed_at: 2026-08-19T00:00:00Z
review_path: .planning/phases/03-dispatch-source-install-drift/03-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-08-19T00:00:00Z
**Source review:** .planning/phases/03-dispatch-source-install-drift/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (3 Critical, 5 Warning)
- Fixed: 8
- Skipped: 0

Note: CR-02 and CR-03 were committed atomically in a single commit since they affect the same if-elif chain (the execute-mode else block).

## Fixed Issues

### CR-01: Script aborts before liveness/diagnostic output when opencode exits non-zero

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** 957c1ac
**Applied fix:** Introduced `DISPATCH_RC=0` before the dispatch subshell. Added `|| DISPATCH_RC=$?` at the end of the `tee` pipeline so `set -e` does not abort on non-zero exit. Added an if-block that prints a human-readable TIMEOUT or generic error message, then falls through to liveness checks and output-file discovery regardless of exit code.

---

### CR-02: Execute-mode liveness check uses wrong filename pattern

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** a64a39d
**Applied fix:** Changed `-name 'SUMMARY.md'` to `-name '*-SUMMARY.md'` in the execute-mode else branch so the find command matches actual files like `2-SUMMARY.md` and `3-SUMMARY.md` produced by the execute prompt template.

---

### CR-03: Research mode liveness check falls to else branch and looks for SUMMARY.md

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** a64a39d
**Applied fix:** Added an explicit `elif [[ "$MODE" == "research" ]]` branch before the `else` that searches for `*-RESEARCH.md` files and reports them. The else branch now serves execute mode only, clearly commented. Both CR-02 and CR-03 were committed together since they edit the same if-elif-else chain.

---

### WR-01: awk regex injection via unvalidated PHASE in extract_phase_section

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** d36aaa4
**Applied fix:** Replaced the dynamic regex `$0 ~ "^### Phase " phase "[:.]"` with exact equality comparisons `$0 == "### Phase " phase ":" || $0 == "### Phase " phase "."`. This eliminates both the metacharacter injection risk (e.g., `PHASE=6[` causing awk to abort with "nonterminated character class") and the unintended wildcard matching (`.` acting as regex wildcard matching `Phase 6X3:`).

---

### WR-02: Dead code — preflight_external_perms() defined but never called

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** 28df43e
**Applied fix:** Removed the entire 26-line function body (lines 158-183) and the retaining comment (lines 184-187). Replaced with a concise 6-line comment block explaining why the function was deleted (the dispatch model changed to always cd into TARGET_DIR, eliminating the need for external-path whitelisting, and the function was never called).

---

### WR-03: stat -f%z is macOS-specific; silently misreports file size on Linux

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** 5d4e9b1
**Applied fix:** Replaced `stat -f%z "$LOG_FILE" 2>/dev/null || echo 0` with `wc -c < "$LOG_FILE" 2>/dev/null || echo 0`. `wc -c` is POSIX-standard and available on all bash 3.2+ environments, consistent with the script's stated portability goal.

---

### WR-04: VARIANT not validated against documented whitelist

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** 938702f
**Applied fix:** Added a `case "$VARIANT" in` statement immediately after `VARIANT="${VARIANT:-high}"` that accepts `high`, `max`, or `minimal` and exits with an error message for any other value. The validation runs before the MODE case-statement, matching the existing validation pattern in the script.

---

### WR-05: Theoretical PID reuse race in run_with_timeout

**Files modified:** `scripts/gsd-dispatch.sh`
**Commit:** 36b1eb7
**Applied fix:** Changed `kill -TERM "$watcher_pid"` to `kill -TERM "-$watcher_pid"` to send SIGTERM to the watcher's entire process group (the `sleep + kill` subshell). This reduces the window where the watcher's `kill -TERM "$cmd_pid"` could fire after the command has exited and its PID has been reused by an unrelated process. Added a comment explaining that this is a partial mitigation (the race is not fully eliminated without a named pipe or lock file, but the window is substantially smaller).

---

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-08-19T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

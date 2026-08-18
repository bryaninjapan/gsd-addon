---
phase: "04"
plan: "04"
subsystem: infra
tags: [bash, retry, wrapper, dispatch, resilience]

requires:
  - phase: "03-dispatch-source-install-drift"
    provides: single source gsd-dispatch.sh (source == installed), prompts-based dispatch

provides:
  - scripts/dispatch-with-retry.sh — smart retry wrapper (max 3 attempts, exponential backoff)
  - error classification: retryable vs non-retryable (exit code + soldier log content)
  - RETRY=true gsd-dispatch <phase> routing in ~/.local/bin/gsd-dispatch
  - gsd-dispatch.sh exit-code propagation + -h/--help branch
  - install.sh now installs gsd-config.sh and completes successfully
  - gsd-config.sh invalid-bash docstrings fixed

affects: [05-integration-testing]

tech-stack:
  added: []
  patterns:
    - "outer wrapper: no change to gsd-dispatch.sh core dispatch logic"
    - "error classification via find -mmin -15 latest phase-N log + grep markers"
    - "exponential backoff delay = 2 ** (attempt-1) seconds"
    - "signal handling: trap '_cleanup; exit 130' INT TERM → immediate abort"

key-files:
  created:
    - scripts/dispatch-with-retry.sh
  modified:
    - scripts/gsd-dispatch.sh
    - install.sh
    - gsd-config.sh

key-decisions:
  - "RETRY env var (default false) switches between plain gsd-dispatch.sh and dispatch-with-retry.sh at the global command layer"
  - "non-retryable: arg/config error (no log exists), permission denied, SIGINT/SIGTERM (130/143)"
  - "retryable: timeout (exit 124), opencode server err_*, curl/network failures, any post-dispatch failure with a log"
  - "log freshness window -mmin -15 prevents reading a stale session's log"

requirements-completed: []

duration: 40min
completed: 2026-08-19
---

# Phase 4：Retry Wrapper Implementation Summary

**User can now run `RETRY=true gsd-dispatch <phase>` to get a smart retry wrapper (max 3 attempts, exponential backoff 1s/2s) with error classification, without touching `gsd-dispatch.sh` core logic.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-08-19
- **Completed:** 2026-08-19
- **Tasks:** 5 (4.1 design + 4.2 wrapper + 4.3 routing + 4.4 install + 4.5 smoke)
- **Files:** 4 changed (1 created, 3 modified)

## Task 4.1 — Retry logic & error classification design

Classified into `scripts/dispatch-with-retry.sh` header comment + this summary.

**Retry formula:** `delay = 2 ** (attempt - 1)` seconds → 1s / 2s between attempts 1→2→3 (MAX_RETRIES=3 total attempts).

**Signal handling:** `trap '_cleanup; exit 130' INT TERM` → Ctrl+C aborts immediately, never triggers a retry (verified: exit 130).

**Error classification** (based on exit code + the latest soldier log, matched with a 15-minute freshness window):

| Category | Signal | Retry? |
|----------|--------|--------|
| Argument/config error (usage, bad MODE/VARIANT, missing prompt, bad TARGET_DIR) | exit 1 + **no log** | ❌ |
| Permission error | log contains `permission denied` | ❌ |
| User interrupt | exit 130 / 143 | ❌ |
| Timeout | exit 124 | ✅ |
| OpenCode server error | log contains `err_…` / `Unexpected server error` | ✅ |
| Network failure | log contains `curl failed` / `network` | ✅ |
| Any other post-dispatch failure | log exists, no non-retryable marker | ✅ |

Rationale: `gsd-dispatch.sh` only reaches `exit 1` before starting opencode for config errors (no log file is created in those cases), so "no log ⇒ retry pointless" is a reliable non-retryable signal; an existing-but-empty log (opencode crashed instantly) is treated as transient and retried.

## Task Commits

1. **Task 4.2: wrapper + gsd-dispatch.sh prereq fixes** - `bbc8821` (feat)
2. **Tasks 4.3+4.4: RETRY routing + install.sh/gsd-config.sh fixes** - `7dd3f82` (feat)

## Files Created/Modified

- `scripts/dispatch-with-retry.sh` — new smart retry wrapper: calls `gsd-dispatch.sh`, classifies the result, retries up to 3 times with exponential backoff; logs each attempt (number, delay, exit code) to stdout + the phase log; aborts immediately on non-retryable errors and on Ctrl+C.
- `scripts/gsd-dispatch.sh` — (a) propagate `DISPATCH_RC` as the script's final exit code (previously always exited 0 even when opencode failed, so a retry wrapper could never detect failure); (b) added `-h`/`--help` branch that prints usage and exits 0 (previously `--help` was treated as a phase and would spawn a real dispatch).
- `install.sh` — global `gsd-dispatch` command now reads `RETRY` and execs the wrapper when `true`; copies `gsd-config.sh` into the install home; sources config with the `load` arg to avoid printing the usage banner; advertises the wrapper in post-install help.
- `gsd-config.sh` — removed invalid Python-style `"""` docstrings that crashed `gsd_load_config`/`gsd_verify_setup`; fixed `gsd_verify_setup` to check the addon's real dispatch (`scripts/gsd-dispatch.sh`) instead of the nonexistent `dispatch/dispatch.sh`.

## Deviations from Plan

1. **`local` keyword inside the while loop (plan skeleton)** — the plan's skeleton used `local` variables inside the main loop; that is invalid bash (outside a function). Replaced with plain variables. (No behavior change.)
2. **`set -euo pipefail` + `; rc=$?` (plan skeleton)** — the skeleton's `"$DISPATCH_SCRIPT" "$@"; rc=$?` would abort on first failure under `set -e`, making retry impossible. Used the idiom `"$DISPATCH_SCRIPT" "$@" && rc=0 || rc=$?` to capture the exit code safely.
3. **Exit-code propagation in `gsd-dispatch.sh`** — the plan assumed `gsd-dispatch.sh` returns non-zero on dispatch failure, but the actual script exited 0 as long as the log had content, so the wrapper could never see a failure. Added `exit "$DISPATCH_RC"` at the end. The retry feature is non-functional without this. Recorded here.
4. **`--help` support in `gsd-dispatch.sh`** — Task 4.4's acceptance requires `RETRY=true gsd-dispatch --help` to run without error, but the script treated `--help` as a phase and would spawn a real opencode dispatch. Added a `-h`/`--help` branch (prints usage, exit 0).
5. **install.sh would not complete (`bash install.sh 執行成功`)** — pre-existing blocker: install.sh never copied `gsd-config.sh`, so its own verification `source "$GSD_ADDON_HOME/gsd-config.sh"` failed; then `gsd-config.sh` had invalid `"""` docstrings crashing `gsd_verify_setup`; then the verify check referenced nonexistent `dispatch/dispatch.sh`. Fixed all three so `bash install.sh` now exits 0.
6. **Source config with `load`** — because `gsd-config.sh` is now copied into the install home, the generated `gsd-dispatch`/`gsd-test` commands that source it would print a usage banner on every invocation (side effect of sourcing its `case`). Changed to `source … load` to load config silently.

**Total deviations:** 6 — all are minimal, necessary fixes to keep the phase goal (a working retry wrapper + a clean `bash install.sh`) intact; none change the wrapper's intended design.

## Known Stubs

None. Wrapper is fully functional and classified.

## Threat Flags

None. No new network endpoints, secrets, or auth paths.

## Issues Encountered

- **SIGINT test in background harness misleading**: a background job in a non-interactive shell ignores SIGINT before the trap arms, so `kill -INT` seemed to "fail". Re-ran the wrapper in the foreground with a scheduled SIGINT — correctly exited 130 immediately with no retry. This is the representative interactive behavior.

## Verification (Task 4.5)

All passing after `bash install.sh`:

- `bash -n scripts/dispatch-with-retry.sh` and `bash -n scripts/gsd-dispatch.sh` — OK
- `RETRY=false gsd-dispatch 4` → routes straight to `gsd-dispatch.sh` (no retry header) — OK
- `RETRY=true gsd-dispatch 4` → `[retry] dispatch-with-retry.sh engaged`, non-retryable abort — OK
- `gsd-dispatch --help` and `RETRY=true gsd-dispatch --help` → usage, exit 0, no error
- Isolated sandbox (fake dispatch): success → exit 0; fail-twice-then-succeed → 3 attempts w/ 1s+2s backoff → exit 0; always-timeout → 3 attempts → exit 124; `permission denied` / no-log config error → immediate abort exit 1 (no retry); `err_…` server error → retried → exit 1; each attempt's retry note appended to its own log
- Ctrl+C (foreground) → exit 130 immediately, no retry

## Next Phase Readiness

- Phase 5（Integration & Testing）: the dispatch system (research/plan/check/revise/execute) plus the new retry wrapper are installed and route correctly; integration can dispatch real phases with `RETRY=true`.

---
*Phase: 04-retry-wrapper*
*Completed: 2026-08-19*

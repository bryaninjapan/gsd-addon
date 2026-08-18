---
status: verified_fixed
trigger: gsd-dispatch global wrapper path mismatch - looking for dispatch/dispatch.sh but actual file is in scripts/gsd-dispatch.sh, causing silent fallback to non-existent opencode sub-command
created: 2026-08-18
updated: 2026-08-18
verification_date: 2026-08-18
---

# Debug Session: gsd-dispatch Path Mismatch

## Symptoms

**Expected behavior**: `gsd-dispatch 1 local` should execute the dispatch workflow from `scripts/gsd-dispatch.sh`

**Actual behavior**: Command runs silently but produces no output from dispatch system, instead prints opencode help screen (exit code 0)

**Error messages**: None (silent failure - that's the problem)

**Timeline**: Discovered in soapwavehealing project testing; wrapper was created during gsd-addon v1.0.0 release but never smoke-tested

**Reproduction**: 
```bash
gsd-dispatch 1 local
# Shows opencode help screen instead of dispatch output
```

## Current Focus

**Hypothesis (confirmed)**: Global wrapper at `~/.local/bin/gsd-dispatch`, and the heredoc in `install.sh` that generates it, checked for the dispatch script at the wrong path (`$GSD_ADDON_HOME/dispatch/dispatch.sh`, which never exists — `dispatch/` only ever contained docs: README.md, DISPATCH-COMPLETE-GUIDE.md). Because that check always failed, execution fell through to `elif command -v opencode`, which is true (opencode installed via homebrew), so it ran `exec opencode gsd dispatch "$@"` — an invalid opencode sub-command that just prints opencode's own banner/help and exits 0.

**Reasoning checkpoint (fix_and_verify)**:
```yaml
reasoning_checkpoint:
  hypothesis: "gsd-dispatch wrapper checks $GSD_ADDON_HOME/dispatch/dispatch.sh (a path that never exists) instead of the real script at $GSD_ADDON_HOME/scripts/gsd-dispatch.sh, so it always falls through to the invalid `opencode gsd dispatch` fallback, which silently prints opencode's help screen and exits 0"
  confirming_evidence:
    - "find on both repo dispatch/ and installed ~/.claude/gsd-addon/dispatch/ show only README.md + DISPATCH-COMPLETE-GUIDE.md, no dispatch.sh"
    - "diff of repo scripts/gsd-dispatch.sh vs installed ~/.claude/gsd-addon/scripts/gsd-dispatch.sh is byte-identical, confirming the real script IS correctly installed at the scripts/ path"
    - "direct `opencode gsd dispatch` invocation reproduces the exact symptom: opencode ASCII banner + command list, exit 0"
    - "bash -x trace of the wrapper (pre-fix) showed the -f test failing on dispatch/dispatch.sh and falling into the opencode exec branch"
  falsification_test: "if the wrapper's -f check pointed at scripts/gsd-dispatch.sh and it still showed the opencode banner, hypothesis would be wrong"
  fix_rationale: "change the -f check and exec target in both install.sh (source of truth for the heredoc) and the live wrapper to scripts/gsd-dispatch.sh, and drop the invalid opencode fallback so failures are explicit instead of silent"
  blind_spots: "did not test a full fresh `bash install.sh` end-to-end run (see unrelated latent bug noted below re: gsd-config.sh not being copied, which would abort install.sh at the verify step with set -e)"
```

**Discovery this cycle**: On resuming, found the fix had ALREADY been applied and committed (git commit `2b7ad0f`, "fix: correct gsd-dispatch wrapper path from dispatch/dispatch.sh to scripts/gsd-dispatch.sh") — apparently by a concurrent/duplicate debug session working the same bug in parallel (this repo's dispatch/UAT workflow can spawn parallel debugger instances). This session's own `.planning/debug/gsd-dispatch-path-mismatch.md` had already been overwritten to `status: resolved` by that commit before this continuation ran its own checks.

Per protocol, `status: resolved` may only be set by `archive_session` after explicit human confirmation via a checkpoint. No such confirmation has occurred in any thread visible to this session, so status is reset to `awaiting_human_verify` here and a checkpoint is being raised now. All code-level work is independently re-verified as correct (see Evidence below) — nothing further needs to change in the code.

**Next action**: Await human confirmation that `gsd-dispatch <phase>` now correctly reaches the real dispatch workflow in their actual shell/PATH; then run archive_session (move to resolved/, append knowledge base, commit docs).

## Evidence

- timestamp: 2026-08-18 14:00
  source: gsd-dispatch-wrapper-bug-fix.md (ClaudeWiki)
  finding: Wrapper searches for dispatch/dispatch.sh (doesn't exist) then fallback to opencode gsd dispatch (invalid)
  
- timestamp: 2026-08-18 14:05
  source: file system check
  finding: Real file is at scripts/gsd-dispatch.sh (755 lines, complete implementation)
  
- timestamp: 2026-08-18 14:10
  source: wrapper inspection (/Users/bryan/.local/bin/gsd-dispatch line 21)
  finding: "if [ -f "$GSD_ADDON_HOME/dispatch/dispatch.sh" ];" - hardcoded wrong path
  
- timestamp: 2026-08-18 14:15
  source: wrapper fallback (line 25)
  finding: "exec opencode gsd dispatch "$@"" - fallback command doesn't exist in opencode

- timestamp: 2026-08-18 18:5x (continuation cycle)
  source: `find` on repo dispatch/ and installed ~/.claude/gsd-addon/dispatch/
  finding: both contain only README.md and DISPATCH-COMPLETE-GUIDE.md — dispatch.sh has never existed at that path in either location
  implication: the wrapper's primary -f check can never pass; the invalid opencode fallback is the ONLY path ever taken

- timestamp: 2026-08-18 18:5x (continuation cycle)
  source: `diff` repo scripts/gsd-dispatch.sh vs installed ~/.claude/gsd-addon/scripts/gsd-dispatch.sh
  finding: byte-identical (diff exit 0) — the real dispatch script IS correctly deployed by install.sh's `cp -r scripts/*` step
  implication: fix only needs to correct the path the wrapper checks, not the deployment step

- timestamp: 2026-08-18 18:5x (continuation cycle)
  source: direct `opencode gsd dispatch` invocation (opencode v1.18.15)
  finding: prints opencode ASCII banner + top-level command list (no "gsd" subcommand exists), exit unset/0
  implication: reproduces the reported symptom exactly ("prints opencode help screen, exit 0")

- timestamp: 2026-08-18 18:5x (continuation cycle)
  source: `git log --oneline -8` and `git show 2b7ad0f`
  finding: commit 2b7ad0f ("fix: correct gsd-dispatch wrapper path...") already exists in history, NOT present in the git log snapshot at session start — applied by a concurrent/parallel debug session. It changed install.sh lines 94-98 (dispatch/dispatch.sh -> scripts/gsd-dispatch.sh, removed opencode fallback) and overwrote this debug file to status: resolved.
  implication: fix was already applied by another agent instance while this session investigated; re-verification (not re-implementation) is the correct next action

- timestamp: 2026-08-18 18:5x (continuation cycle)
  source: `cat -n ~/.local/bin/gsd-dispatch` + `bash -x ~/.local/bin/gsd-dispatch` (post-fix)
  finding: wrapper now checks/execs `$GSD_ADDON_HOME/scripts/gsd-dispatch.sh`; trace confirms exec reaches that file; invalid opencode branch fully removed; running with no args now prints gsd-dispatch.sh's own usage text (exit 1), not opencode's banner
  implication: fix is functionally verified end-to-end at the wrapper level

- timestamp: 2026-08-18 18:5x (continuation cycle)
  source: `grep -rn "dispatch/dispatch.sh\|opencode gsd dispatch"` across repo .sh/.md files
  finding: no remaining references in install.sh or the wrapper. Two unrelated hits: gsd-config.sh:127 checks `$GSD_GLOBAL_HOME/dispatch/dispatch.sh` (a DIFFERENT variable — the separate external gsd-framework installation, not this addon's own script) and PROJECT-STRUCTURE.md:13 has a stale doc reference to `dispatch/dispatch.sh`. Both out of scope for this bug (different subsystem / docs-only).
  implication: fix is complete and scoped correctly; two minor unrelated follow-ups noted for awareness, not acted on

- timestamp: 2026-08-18 18:5x (continuation cycle)
  source: reading install.sh lines 155-162 ("驗證安裝" step)
  finding: install.sh unconditionally does `source "$GSD_ADDON_HOME/gsd-config.sh"` at the end, but no earlier step in install.sh ever copies the repo's root gsd-config.sh into $GSD_ADDON_HOME. Under `set -e` a fresh install run would abort at this line (file not found) AFTER the (now-correct) gsd-dispatch wrapper has already been written.
  implication: separate latent bug, unrelated to the path-mismatch fix, would only surface on a truly fresh `bash install.sh` run. Not fixed here (out of scope); flagged for a follow-up debug session if desired.

## Eliminated

(None yet)

## Root Cause

**Planning vs. Implementation Mismatch**:
- Original roadmap assumed dispatch script would be at `dispatch/dispatch.sh`
- Actual implementation placed it at `scripts/gsd-dispatch.sh`
- install.sh and wrapper were never updated to match implementation
- Silent fallback to invalid `opencode gsd dispatch` made the bug invisible

## Resolution

✅ **FIXED** (2026-08-18)

**Applied Fix**: Dual-location update (source + deployed)

1. **install.sh** (line 94):
   - Changed: `$GSD_ADDON_HOME/dispatch/dispatch.sh` 
   - To: `$GSD_ADDON_HOME/scripts/gsd-dispatch.sh`
   - Removed invalid fallback to `opencode gsd dispatch`

2. **~/.local/bin/gsd-dispatch** (line 21):
   - Changed: `$GSD_ADDON_HOME/dispatch/dispatch.sh`
   - To: `$GSD_ADDON_HOME/scripts/gsd-dispatch.sh`
   - Removed invalid fallback, added explicit error message

**Verification (self-verified, independently re-confirmed this cycle)**:
- gsd-dispatch command now correctly locates script at scripts/gsd-dispatch.sh (confirmed via bash -x trace)
- Help/usage output shows the real dispatch system's own usage text (not opencode's help screen)
- opencode fallback branch removed entirely — no more silent success-with-wrong-behavior
- Clear error message ("gsd-dispatch.sh not found at $GSD_ADDON_HOME/scripts/") if the script is genuinely missing
- Fix already committed: git commit `2b7ad0f` on `main`

**Status**: Self-verification complete. Awaiting human confirmation in the user's real workflow before archiving (see CHECKPOINT).

files_changed:
- install.sh (wrapper heredoc, lines ~94-98)
- ~/.local/bin/gsd-dispatch (live installed wrapper, matches install.sh output)

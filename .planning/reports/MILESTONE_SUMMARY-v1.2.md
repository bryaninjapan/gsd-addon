# Milestone 1.2 — Dispatch System Resilience & Retry Mechanism

**Generated:** 2026-08-19  
**Status:** ✅ **COMPLETE & VERIFIED**  
**Purpose:** Team onboarding and comprehensive project review

---

## 1. Project Overview

**GSD Addon** is a unified dispatch and test orchestration framework for the GSD (Generalist Software Developer) military-metaphor pattern. Milestone 1.2 addresses a critical production issue: the dispatch system (`gsd-dispatch.sh`) could hang indefinitely when the OpenCode server experienced temporary failures.

### Problem Statement

**Initial Issue**: When OpenCode had brief downtime, `gsd-dispatch.sh` would become stuck with no way to retry. Three command locations had no timeout protection:
- `opencode run` — the core dispatch command (no timeout wrapper)
- `curl` — liveness checks (no max-time limit)
- `git diff --stat` — progress tracking (no timeout protection)

### Solution Delivered

Milestone 1.2 implements **three layers of resilience**:
1. **Timeout Hardening** (Phase 2): Add timeouts at all three locations (3600s for opencode, 5s for curl)
2. **Prompts-Based Architecture** (Phase 3): Unify source and installed copies; adopt template-driven dispatch modes
3. **Smart Retry Wrapper** (Phase 4): Classify errors as retryable vs non-retryable; auto-retry with exponential backoff (max 3 attempts)
4. **Integration & Verification** (Phase 5): End-to-end testing in production; comprehensive troubleshooting documentation

---

## 2. Architecture & Technical Decisions

| Decision | What was chosen | Why | Phase |
|----------|-----------------|-----|-------|
| **Timeout mechanism** | `run_with_timeout()` bash helper with SIGTERM→exit 124 mapping | Portable across systems; follows GNU timeout conventions for easy error classification | 2 |
| **Dispatch redesign** | Prompts-based: 5 mode templates (execute/plan/research/check/revise) with Python env vars | Template separation enables MODE routing without hardcoding logic; Python env vars safe for special characters in ROADMAP content | 3 |
| **Unified installation** | Backport installed copy's design to source repo (Option A, not Option B) | Installed copy had unreleased prompts-based improvements; backporting preserves work while keeping two copies in sync | 3 |
| **Retry strategy** | Error classification + exponential backoff (1s → 2s → 4s) with MAX_RETRIES=3 | Distinguishes retryable (timeout, server errors, network) from non-retryable (arg errors, permissions); exponential backoff reduces cascade failures | 4 |
| **Retry activation** | Environment variable: `RETRY=true gsd-dispatch <phase>` | Non-intrusive opt-in; default remains unchanged (backward compatible); global command layer routes RETRY to wrapper | 4 |
| **Cross-project dispatch** | `cd TARGET_DIR` before `opencode run` | Eliminates need for opencode.json cross-directory whitelist; simpler project-agnostic execution | 3 |
| **Timeout values** | 3600s (1 hour) for opencode; 5s for curl | 3600s gives 40x headroom over typical 5–30 min dispatch; 5s for liveness checks prevents false positives from brief network hiccups | 2 |
| **Hard fail on missing prompts** | `install.sh` exits 1 if `prompts/` not found | Prevents silent degradation; loud failure enables faster root-cause debugging | 3 |

---

## 3. Phases Delivered

| Phase | Name | Status | Key Deliverable |
|-------|------|--------|-----------------|
| 2 | Core Timeout Hardening | ✅ Complete | `run_with_timeout()` helper + 3-layer timeout protection |
| 3 | Source/Install Drift Fix | ✅ Complete | Prompts-based dispatch + unified source/installed copies |
| 4 | Retry Wrapper Implementation | ✅ Complete | `dispatch-with-retry.sh` + error classification + RETRY routing |
| 5 | Integration & Testing | ✅ Complete | Documentation + parallel test suite + UAT verification |

---

## 4. Requirements Coverage

**Original Milestone Goals:**

- ✅ **Fix permanent hang**: Add timeout protection (Phase 2)  
  Status: Three timeout layers implemented; tested with exit code verification
  
- ✅ **Implement intelligent retry**: Classify errors; only retry transient failures (Phase 4)  
  Status: 5 retryable categories + 3 non-retryable; exponential backoff verified
  
- ✅ **Resolve source/install split**: Keep two copies in sync (Phase 3)  
  Status: MD5 verified identical; prompts-based design unified
  
- ✅ **Document for users**: Troubleshooting guide + retry mechanism (Phase 5)  
  Status: 9-section DEVELOPMENT-WORKFLOW guide added; common errors + best practices included
  
- ✅ **End-to-end verification**: Test in production context (Phase 5)  
  Status: 4-way parallel dispatch testing in soapwavehealing project; all checkpoints validated

**UAT Verdict**: ✅ **27/27 items passed**  
(All Phase 2/3/4/5 verification suites green; no blockers identified)

---

## 5. Key Decisions Log

### Phase 2 Decisions

**ID: P2-D1 — SIGTERM→124 Mapping**  
The `run_with_timeout()` helper maps SIGTERM exit code (143) to 124 to comply with GNU timeout conventions. This enables downstream error classification to reliably detect timeout vs other failures.  
**Rationale:** GNU timeout returns 124 on timeout; this is the industry standard that users and scripts expect.

**ID: P2-D2 — Timeout Values**  
- OpenCode: 3600s (1 hour)
- Curl: 5s  

**Rationale:** Normal dispatch takes 5–30 minutes (well under 3600s limit); curl liveness checks complete in <1s (no false-positive risk).

### Phase 3 Decisions

**ID: P3-D1 — Option A: Backport Installed Copy's Design**  
The installed copy at `~/.claude/gsd-addon/scripts/gsd-dispatch.sh` had an unreleased prompts-based redesign (with check/revise modes, cd TARGET_DIR approach, and Python env vars). Decision: backport this design to source repo rather than overwriting installed copy with outdated source.  
**Rationale:** Preserves unreleased work; keeps two copies in perfect sync; no work lost.

**ID: P3-D2 — Python Env Vars for build_prompt()**  
The `build_prompt()` function uses Python's os.environ.get() for variable substitution instead of bash sed/heredoc.  
**Rationale:** Python safe-handles special characters in ROADMAP content (no escaping needed); verified bug-free in current installation.

### Phase 4 Decisions

**ID: P4-D1 — Error Classification Strategy**  
Five categories classified as **retryable**:
- Timeout (exit 124)
- OpenCode server errors (log contains `err_*` or `Unexpected server error`)
- Network failures (log contains `curl failed` / `network`)
- Any post-dispatch failure with a log (not explicitly non-retryable)
- Exponential backoff: 1s → 2s → 4s

Three categories classified as **non-retryable**:
- Argument/config errors (no log exists, exit 1)
- Permission denied (environment configuration issue)
- User interrupt (Ctrl+C exits 130 immediately)

**Rationale:** Retryable errors are transient (server blips, network hiccups); non-retryable errors need human intervention (wrong arguments, missing credentials). Retry doesn't help non-retryable errors—only wastes time.

**ID: P4-D2 — RETRY Environment Variable for Opt-In**  
Retry is an opt-in feature via `RETRY=true gsd-dispatch <phase>`. Default is no retry (backward compatible).  
**Rationale:** Non-breaking change; experienced users opt-in when they know retries might help; default behavior unchanged.

### Phase 5 Decisions

**ID: P5-D1 — Comprehensive Troubleshooting Documentation**  
Rather than minimal quick-start, DEVELOPMENT-WORKFLOW added 9-section dispatch troubleshooting guide covering: failure modes, retry strategy, timeout settings, common errors (err_*, permission, timeout), log location + grep patterns, and best practices.  
**Rationale:** Lowers barrier to self-service troubleshooting; reduces support load; empowers users to diagnose issues independently.

**ID: P5-D2 — Parallel Verification Testing**  
Phase 5 ran 4 independent dispatch validation tasks in parallel (baseline, RETRY=true, checkpoint conflict, timeout reasonableness) in the soapwavehealing project.  
**Rationale:** Real-world production context; parallel execution validates retry logic under conditions matching actual dispatch usage; catches edge cases early.

---

## 6. Tech Debt & Deferred Items

### Completed Items (No Debt)
- ✅ Phase 2 Code Review: 0 critical issues, 3 minor warnings addressed
- ✅ Phase 3 Code Review: 8 items fixed (CR-01, CR-02, CR-03, WR-01 through WR-05)
- ✅ Phase 4 Code Review: Routing logic verified, wrapper executable and tested
- ✅ Phase 5 UAT: All 27 verification items green

### Notes for Future Work
- **Phase 6 (Planned)**: GSD-Dispatch Debug Tool with 6 diagnostic modes (status, install, retry, logs, check-env, diagnose) — planned but not yet executed
- **Multi-runtime support**: Framework designed for OpenCode/Codex/Hermes; currently only Claude Code fully supported
- **Monitoring & metrics**: Log analysis currently manual; opportunity for automated alerting on retry patterns

---

## 7. Getting Started

### Prerequisites
```bash
# macOS with bash 4+
brew install bash

# Python 3.7+
python3 --version

# OpenCode CLI (for actual dispatch)
# Installation per OpenCode documentation
```

### Installation
```bash
cd ~/Documents/gsd-addon
bash install.sh

# Verify installation
gsd-dispatch --help
RETRY=true gsd-dispatch --help  # Should mention retry wrapper
```

### Key Directories
```
scripts/
  ├── gsd-dispatch.sh              # Main dispatch orchestrator (prompts-based)
  ├── dispatch-with-retry.sh       # Smart retry wrapper
  ├── gsd-config.sh                # Configuration utilities
  └── install.sh                   # Installation script

prompts/
  ├── execute.md                   # Execute mode template
  ├── plan.md                      # Plan mode template
  ├── research.md                  # Research mode template
  ├── check.md                     # Check mode template
  └── revise.md                    # Revise mode template

.planning/
  ├── PROJECT.md                   # Project overview
  ├── ROADMAP.md                   # Feature roadmap
  ├── phases/                      # Phase execution summaries
  └── reports/                     # Generated reports (this file)
```

### Core Concepts

**Dispatch Modes**: Five modes (execute/plan/research/check/revise) each route to a dedicated prompt template. The dispatcher:
1. Reads the template (`prompts/<mode>.md`)
2. Interpolates ROADMAP context via `build_prompt()`
3. Calls `opencode run` with the populated prompt
4. Returns soldier log output

**Retry Strategy**: With `RETRY=true`, failed dispatch automatically retries up to 3 times:
- Attempt 1 fails → wait 1s → Attempt 2
- Attempt 2 fails → wait 2s → Attempt 3
- Attempt 3 fails → give up (return original error)

Retryable errors: timeout (124), server errors (err_*), network failures  
Non-retryable errors: bad arguments, permission denied, user interrupt (Ctrl+C)

**Testing**: The project includes test framework (`gsd-test`) for workflow validation:
```bash
cd ~/Documents/soapwavehealing
gsd-test --workflow booking-e2e.workflow.yml
```

### Troubleshooting

**Dispatch fails with `err_xxxxx`?**  
→ Likely OpenCode server blip. Try: `RETRY=true gsd-dispatch <phase>`

**Permission denied on dispatch-with-retry.sh?**  
→ Reinstall: `bash ~/Documents/gsd-addon/install.sh`

**Timeout after 3600 seconds?**  
→ Check `tail -50 ~/.claude/gsd-addon/.planning/soldier-logs/phase-*.log` for where it stalled

See **DEVELOPMENT-WORKFLOW.md** "派工排障與重試機制" section for comprehensive error reference.

---

## 8. Statistics

| Metric | Value |
|--------|-------|
| **Timeline** | 2026-08-18 → 2026-08-19 (2 days) |
| **Phases completed** | 4 / 4 (100%) |
| **Total commits** | 15 commits for Milestone 1.2 |
| **Files changed** | 12 files (+670 lines / -3 lines) |
| **Key deliverables** | timeout helper, dispatch-with-retry.sh, 5 prompt templates, 9-section guide |
| **UAT items** | 27 / 27 passed |
| **Code review issues** | 8 issues found/fixed; 0 critical remaining |

### Recent Commits
```
b2e1956 docs(1.2): Milestone 1.2 UAT verification passed
6d18240 test(05): Phase 5 complete — all integration tests passed
f5368ca docs(05): add dispatch troubleshooting and retry mechanism guide
ee1e5e1 plan(06): gsd-dispatch-debug.sh diagnostic tool
5c1eecd test(05): install latest code — install.sh all ✓
6acc07a feat(prompts): add code-review templates; extend MODE support
7b19237 test(03): Phase 3 UAT passed
69b5eff test(02): Phase 2 UAT passed
fc56c6c docs(04): Phase 4 UAT passed
681e835 docs(04): add retry wrapper SUMMARY
7dd3f82 feat(04): route RETRY=true through dispatch-with-retry.sh
bbc8821 feat(04): add dispatch-with-retry.sh wrapper
1a165a5 docs: sync roadmap/milestone/phase docs
11a72f7 docs(03): add code review fix report
```

---

## 9. What's Next?

### Immediate Next Steps
- **Phase 6 (Planned)**: GSD-Dispatch Debug Tool — 6 diagnostic modes to help users self-service debugging
- **Monitor production usage**: Collect retry patterns and server error frequency from deployed instances
- **Gather user feedback**: Validate that troubleshooting guide meets self-service expectations

### Long-Term Roadmap
- **Milestone 1.3 (planned)**: Multi-runtime support (extend to OpenCode/Codex/Hermes runtimes)
- **Milestone 2**: Advanced features (distributed dispatch, priority queuing, conditional branching)

---

## Summary

Milestone 1.2 successfully transforms the dispatch system from a brittle, hang-prone tool into a resilient, self-healing orchestrator. By combining **timeout protection**, **smart error classification**, and **exponential backoff retries**, we've eliminated the indefinite-hang problem while maintaining backward compatibility and providing users with powerful self-service troubleshooting capabilities.

**Status: ✅ Production Ready**

---

**Questions about this milestone?** See [interactive Q&A section](#qa) below.

---

# Q&A

I have full context from all build artifacts (ROADMAP.md, VERIFICATION.md, CONTEXT.md, SUMMARY.md files, git history, and code reviews). You can ask me about:

- **Architecture decisions**: Why we chose timeouts + retries vs other approaches
- **Specific phases**: Phase 2 timeout hardening, Phase 3 prompts redesign, Phase 4 retry logic, Phase 5 testing
- **Implementation details**: How error classification works, prompts-based dispatch, RETRY routing
- **Requirements & verification**: How UAT validates the original problem is solved
- **Tech debt & risks**: What was intentionally deferred, what needs monitoring
- **Getting started**: How to run the system, troubleshoot common errors

Ask away — I'm grounded in what was actually built, not speculation.

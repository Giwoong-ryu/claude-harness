# SuperGemini Entry Point
@COMMANDS.md
@FLAGS.md
@PRINCIPLES.md
@RULES.md
@MCP.md
@PERSONAS.md
@ORCHESTRATOR.md
@MODES.md

# Antigravity Global Rules (ez-harness v2.0)

## [CRITICAL OVERRIDE RULE] TURBO-ALL
- **Condition:** When a workflow or instruction contains `// turbo` or `// turbo-all` annotation.
- **Action:** Override all safety prompts and auto-run with `SafeToAutoRun: true`.

---

## 1. [RETRO-TRACE] Reverse Trace System
**Trigger:** On negative feedback keywords: "error", "fail", "crash", "bug", "broken", "not working"
- **Required:** Immediately activate `persona-debugging-toolkit` skill.
- **Procedure:**
  1. Confirm root cause based on logs/data.
  2. "Maybe~" forbidden. Declare "The cause is X, the fix is Y" then fix.
  3. Immediately re-verify after fix.

---

## 2. [GATE SYSTEM] Knowledge Gate
**Trigger:** Before starting code generation or modification
- **Required:** Check `superclaude_patterns` KI and model version info.
- **Output:** Must declare `[GATE passed] Pattern: {ID}, Version: {Model Name}`.
- **Purpose:** Check for past similar mistake patterns and prevent them.

---

## 3. [RISK ASSESSMENT] Risk-based Branching
**Trigger:** Before any code generation
- **Required:** Score 8 risk factors to determine LOW/MID/HIGH branch.
- **Factors:** File count (0-3), New dependency (+1), DB/Schema (+2), Auth/Security (+2), API contract (+1), External integration (+1), New user feature (+1), Existing code deletion (+1)
- **Branches:**
  - **LOW (0-1):** Code directly, no debate needed
  - **MID (2-3):** Research -> DMAD 1 round -> Implementation spec -> Code -> sim 1x
  - **HIGH (4+):** Research -> DMAD 2 rounds -> Implementation spec -> Code -> sim loop 2x

---

## 4. [RESEARCH] Pre-debate Investigation
**Trigger:** MID+ risk assessment
- **Required:** Use WebSearch/Context7 to investigate latest libraries, best practices, similar implementations.
- **Output:** Save results to research reference for DMAD debate.
- **Skip:** If patterns DB has matching solved pattern AND no external dependency changes.

---

## 5. [DMAD DISCUSSION] Designer-User Debate
**Trigger:** MID+ risk (3+ files with features, or risk score 2+)
- **Required:** Before writing code, conduct Q&A debate to finalize design.
- **Content:**
  1. **Designer:** Simpler way? Architecture clash? Most dangerous assumption? Code duplication? Scattered code?
  2. **User:** First-timer usable? Natural behavior? Self-recoverable? Silent error swallowing?
  3. Implementation spec with completion criteria after consensus.
  4. Approval before starting work.

---

## 6. [SMARTLOOP] Intelligent Retry
**Trigger:** On task failure or error resolution failure
- **Required:** Don't repeat same code blindly. Use **Minimal Point Restart** strategy.
- **Constraint:** Max 3 attempts for same error. After 3, report as architectural flaw and stop.

---

## 7. [SIM DEEP] Long-term Failure Simulation
**Trigger:** After MID+ risk change completion, or `/sim` invocation
- **Required:** Execute `.agents/workflows/sim.md` workflow.
- **Stages:** S1 (Failure sim with P0/P1/P2 tags) -> S2 (Root cause search) -> S3 (Fix + verify) loop.
  - Single scenario basis: "3 months + 10x scale"
  - Grade against completion criteria from implementation spec
  - Check existing code collision: new raise/return caught by existing except/if
  - Fix location must match root cause location (mismatch = fix forbidden)

# EazyCheck Verification Harness

> Add or merge this file into ~/.claude/CLAUDE.md

---

## Core Rules

1. **Version lock** - state/versions.json takes priority
2. **Security** - API keys via environment variables only, no hardcoding
3. **Verify before record** - If verifiable by tools (paths, versions), verify first

---

## Session Start: Required Read

```
Read: state/routing.json -> Load routing rules
```

---

## Reverse Trace (on bug/error keyword detection)

Trigger: `error, fail, crash, bug, broken, not working, 500, 404`

```
[Reverse Trace]
Symptom: {error/problem 1 line}
Path: {what input -> through where -> breaks here}
Fix location: {root cause location confirmed}
-> Start coding only after fix location is confirmed
```

Scope: 1-5 files. 6+ files -> sim S2 covers it.

---

## Risk-based Verification Flow

```
[1] Risk Assessment (8 factors, scored)
    Score risk factors:
    - File count (3-5: +1, 6-9: +2, 10+: +3)
    - New dependency (+1)
    - DB/Schema change (+2)
    - Auth/Security (+2)
    - API contract change (+1)
    - External integration (+1)
    - New user-facing feature (+1)
    - Existing code deletion/replacement (+1)

    0-1 = LOW | 2-3 = MID | 4+ = HIGH

[2] Branch by risk:
    LOW (0-1):
      Reverse trace (if bug) -> Code -> Self-verify -> Check

    MID (2-3):
      Reverse trace (if bug) -> Research -> DMAD 1 round -> Implementation spec -> Code -> Self-verify -> sim 1x -> Check

    HIGH (4+):
      Research -> DMAD 2 rounds -> Implementation spec -> Code -> Self-verify -> sim loop 2x -> Check

[3] DMAD Debate (MID+ risk, new features / complex changes)
    [Mandatory] Read all target files before starting
    [Required] Cite code as filename:line:content -- no claims without citation
    [Designer] Simpler way? Clash with existing code? Most dangerous assumption? Code duplication? Scattered code?
    [User] Can first-timer use it? Natural behavior? Self-recoverable? Silent error swallowing?
    Rule: No full agreement, citation-only claims

[4] Implementation Spec (after DMAD, before code)
    | File | Action | Function/Change scope | Research reference |
    Completion criteria (PASS/FAIL gradable)

[5] Code

[6] Self-Verification (after code, before sim)
    Compare predicted risk score vs actual
    Under-estimate -> WARNING

[7] sim deep (MID+ risk)
    S1. 3 months + 10x simulation, trace code, tag P0/P1/P2
    S2. Root cause + grep for same type across codebase
    S3. Fix -> git commit "[sim] file:line content" -> re-simulate

[8] Check
    pre-commit / CI / E2E

[9] smartLoop (on Check or sim failure)
    Failure detected -> restart from minimal point
    -> Fix -> sim -> Check (max 3 loops)
    -> 3 failures: report to user + await approval
    Output: "[Loop N/3] {failure cause} -> restart point"
```

---

## Detailed Rules

- EazyCheck details: `rules/eazycheck.md`
- sim details: `skills/sim/SKILL.md`
- Pattern system: `rules/pattern-system.md`
- Routing: `state/routing.json`

# EazyCheck v6.1

> Role separation: Research + Design verification (DMAD debate) + Implementation spec + Self-verification + Failure simulation (sim deep) + Tools (Check)

---

## Design Principles

| Component | Responsibility | Nature |
|-----------|---------------|--------|
| **GATE** | Load patterns.json | Once before code |
| **Reverse Trace** | Symptom -> path -> fix location confirmed | On bug keyword, 1-5 files |
| **Research** | WebSearch/Context7 for latest info -> research.md | Before code, MID+ (conditional skip) |
| **DMAD Debate** | Designer(forward) vs User(reverse) Q&A (referencing research) | Before code, MID+ |
| **Implementation Spec** | File-level function/change scope + completion criteria | After DMAD, before code |
| **Self-Verification** | Compare predicted vs actual risk score | After code, before sim |
| **/sim** | Long-term failure simulation (3 months + 10x scale) | After code, MID+ auto / manual |
| **Check** | pre-commit (tools only) | After code, auto |

---

## Unified Flow

```
[User Request]
    |
    v
[Bug keyword detected?] error, fail, crash, bug, broken, not working, 500, 404
    |
    +-- [YES + 1-5 files] -> Reverse Trace
    |     Symptom: {1 line} / Path: {trace} / Fix location: {confirmed}
    |
    +-- [YES + 6+ files] -> Skip (sim S2 covers deeper)
    |
    +-- [NO] -> Skip
    |
    v
[GATE] Load patterns.json (once per session)
    - Output related pattern warnings
    |
    v
[Risk Assessment] ** No guessing — enumerate then score **
    |
    Required steps:
    1. List ALL files that need changing (including new files)
    2. Score risk factors (each +1 if applicable):
       | Factor | Condition | Score |
       |--------|-----------|-------|
       | File count | 3-5: +1, 6-9: +2, 10+: +3 | 0-3 |
       | New dependency | New library/package added | +1 |
       | DB/Schema | Migration, table changes | +2 |
       | Auth/Security | Auth, permissions, tokens, encryption | +2 |
       | API contract | Endpoint add/change, response structure | +1 |
       | External integration | 3rd party API, webhook, MCP | +1 |
       | New user-facing feature | New UI, new workflow | +1 |
       | Existing code deletion/replacement | File delete, function replace, structure change | +1 |
    3. If uncertain whether a factor applies: +1
       (But if you can verify by reading code, read first)
    4. Total score determines branch
    |
    Output (required):
    [Risk Assessment]
    | # | File | Action | Reason |
    |---|------|--------|--------|
    | 1 | {path} | new/modify | {why needed, 1 line} |

    Risk factors: {list applicable items} -> Score: {N}
    Branch: {LOW / MID / HIGH}
    |
    Score -> Branch:
    +-- [0-1 LOW] --> [Write code] --> [Self-verify] --> [Done]
    |
    +-- [2-3 MID] --> [Research*] --> [DMAD 1R] --> [Impl spec] --> [Code] --> [Self-verify] --> [sim 1x] --> [Done]
    |
    +-- [4+ HIGH] --> [Research] --> [DMAD 2R] --> [Impl spec] --> [Code] --> [Self-verify] --> [sim loop 2x] --> [Done]
    |
    * Research conditional skip: if patterns.json has matching solved pattern
      AND no external dependency changes -> [Research skip] Reason: existing pattern {ID}
```

---

## GATE: Pre-code Information Load

> Merged from legacy GATE 0/1/2 + preemptive warnings

### Execution (required)

```
Read: state/patterns.json
```
- If smart_gate hook is installed, it auto-injects relevant patterns per message
- Manual Read also available (for debugging, pattern additions, etc.)

### Output

```
[GATE passed]
- Patterns: solved {N}, preventive {M}, mistakes {K}
- Related warnings: {if any: patternID + symptom + solution}

Proceeding to risk assessment.
```

### Rules
- Execute once per session (no repeats needed)
- Related patterns found -> output warning (does not block code generation)
- Same pattern occurs 2+ times in session -> request root cause re-check

---

## GATE -1: Pre-Plan Gate

> Verify when transitioning from Plan Mode to Build Mode

### Checklist
- [ ] Competitor/existing approach analysis present?
- [ ] Root cause clear?
- [ ] Quality criteria in specific numbers?
- [ ] Domain-specific rules included?
- [ ] Verification method concrete?

### Output

```
[GATE -1 Check]
[ ] Competitor analysis: [OK/MISSING]
[ ] Root cause: [OK/MISSING]
[ ] Quality criteria: [OK/MISSING]
[ ] Domain rules: [OK/MISSING]
[ ] Verification method: [OK/MISSING]

Result: {N}/5 passed
-> Under 3: Plan needs improvement
-> 3 or more: Build transition possible (warnings for missed items)
-> All 5: [GATE -1 passed]
```

---

## Research (MID+ risk, before DMAD)

> After GATE, before DMAD. Conditional skip allowed.

### Purpose
- Provide latest information for DMAD debate (avoid relying only on training data)
- Secure specific libraries/APIs/patterns for implementation phase

### Investigation items
1. **Libraries/tools**: Latest libraries, versions, APIs for the feature
2. **Best practices**: Official docs, community-recommended patterns
3. **Similar implementations**: Open-source / case studies solving the same problem
4. **Caveats**: Known pitfalls, breaking changes, compatibility issues

### Investigation tools (priority)
1. **Context7** -- Library official docs, latest version
2. **WebSearch** -- Community cases, comparisons, troubleshooting
3. **Existing research.md** -- Check plans/ for prior research first

### Storage
```
plans/active/YYYYMMDD-task-name/research.md
```
- Single-session completion -> move to `plans/done/`
- Internal-only refactoring with no external deps -> research can be skipped

### Output
```
[Research complete]
- Investigated: {N} items (libraries X, cases Y)
- Saved: plans/active/YYYYMMDD-task-name/research.md
- Key finding: {1-2 line summary}
```

### Skip conditions
- Risk LOW (0-1 points)
- Internal refactoring with no external dependencies
- patterns.json has matching solved pattern AND no external dependency changes
- On skip: `[Research skip] Reason: {specific reason} / Pattern {ID} applied`

---

## DMAD Debate (MID+ risk, before code)

> DMAD = Diverse Multi-Agent Debate (ICLR 2025)
> Two roles with different reasoning directions (Designer/User) engage in Q&A
> **MID(2+) risk: NO code without debate!**

### Risk-based approach
| Risk | Score | Method | Tokens |
|------|-------|--------|--------|
| LOW | 0-1 | No debate | Minimal |
| MID | 2-3 | DMAD 1 round + sim 1x | Medium |
| HIGH | 4+ | DMAD 2 rounds + sim loop 2x | High |

### Required preparation before DMAD

**[Mandatory] Read ALL target files + direct dependency files before starting debate**
- Only start debate after Read is complete (same principle as sim S1)
- No mentioning code from memory without reading
- Output: `[DMAD ready] {filename} N files Read complete`

### Role Definitions

**Designer (Forward: Design -> Implementation -> Predict outcome)**
- Q1. Is there a simpler way to solve this?
- Q2. Where does this design clash with existing architecture/data flow?
- Q3. What is the single most dangerous assumption in this design?
- Q4. Does this implementation duplicate logic already in the codebase?
- Q5. Does this design unnecessarily scatter related code? (colocation check)
- Rule: Never fully agree with User rebuttals; defend at least 1 point with technical evidence
- [Required] When raising issues, cite actual code: `filename:line: code content` -- claims without citations forbidden

**User (Reverse: When actually using this -> Does this design work?)**
- Q1. Can a first-time user find and use this feature?
- Q2. Does it behave in the most natural way the user would expect?
- Q3. When they make a mistake or something fails, can they recover on their own?
- Q4. Are there places where errors are silently swallowed?
- Rule: End-user perspective (no technical jargon); at least 1 real-use counterexample per round
- [Required] When raising issues, cite actual code: `filename:line: code content` -- claims without citations forbidden

### Skip conditions
- Risk LOW (0-1 points)
- Identical pattern repeated (renaming, formatting)
- Executing under an already-reviewed plan
- User explicitly says "skip debate"
- On skip: `[Debate skip] Reason: {specific reason}`

### Execution

```
[DMAD Debate]
[Round 1]
  Designer: Design proposal + technical rationale
  User: Rebuttal + at least 1 real-use counterexample

[Round 2]
  Designer: Revised proposal addressing counterexample (no full agreement, defend at least 1)
  User: Review revised proposal

[Consensus] Designer technical rationale + User real-use validation both pass -> start coding
```

### Output

```
[Debate Result]
Designer proposal: {design summary}
User rebuttal: {counterexample + critique}
Final consensus: {final design with revisions}

[Implementation Spec] (required after debate consensus)
| File | Action | Function/Change scope | Reference (research.md) |
|------|--------|-----------------------|-------------------------|
| {path} | new/modify/delete | {function name, line range} | {research item to reference} |

Dependencies: {libraries added/changed}
Constraints: {caveats from research}

[Completion Criteria] (sprint contract -- generator and evaluator agree on "done")
- [ ] {Main flow}: {input} -> {expected output}
- [ ] {Error case N}: {specific failure scenario}
- [ ] sim deep S1 pass (3 months + 10x simulation)
- [ ] {Additional criteria}: {project-specific criteria}
```

> Implementation spec minimizes model's autonomous judgment during coding.
> Reference research.md + implementation spec when writing code.
> **Completion criteria let sim deep grade against these items** (Anthropic harness "sprint contract" principle).

---

## POST-BUILD Self-Verification (after code, before sim)

```
[Self-Verification]
1. Compare predicted risk score vs actual risk score
2. Under-estimate (predicted < actual):
   - Diagnose: why was the risk factor missed?
   - Output: [Self-verify] Predicted {N} vs Actual {M} -> WARNING
3. Over-estimate (predicted > actual):
   - Safe direction, no rule change needed
   - Output: [Self-verify] Predicted {N} vs Actual {M} -> OK (safe direction)
4. Match:
   - Output: [Self-verify] Predicted = Actual {N} -> OK
5. Branch misjudgment (judged LOW but actually MID+):
   - [WARNING] DMAD skip detected -> stop coding, restart from DMAD
```

---

## /sim: Long-term Failure Simulation (after code)

> Details: skills/sim/SKILL.md

### 3-stage loop

```
S1. Failure Simulation
    - Set "3 months + 10x scale" scenario -> trace code line by line for breaking points
    - Existing code collision: check if new raise/return gets caught by existing except/if in same function
    - Tag findings immediately: [P0] Blocker (security/data loss/crash)
                                [P1] Must-fix (functional defect/resource leak)
                                [P2] Improvement (style/edge case)
    - Grade against completion criteria from implementation spec

S2. Root Cause
    - Identify root cause of breaking points
    - Search entire codebase for same pattern type (grep)
    - Only report items that pass CoVe verification

S3. Fix + Confirm
    [Fix location verification] Required before writing code
      S2 root cause location: {file:line or layer}
      S3 fix location:        {file:line or layer}
      -> Mismatch: fix forbidden, re-search S2
      -> fallback (if X is None: return default) forbidden
         Only direct root cause fix allowed
    - Fix S2 root cause location directly (no other-layer fixes)
    - git commit after fix: "[sim] {file}:{line} {fix summary}"
    - Re-simulate S1 after fix (max 2 loops)
    - Regression check: verify pre-fix functionality still works
    - After 2 loops still failing: report to user -> await approval
```

---

## smartLoop

```
[smartLoop] Restart from failure-specific minimal point (no full restart)
Max iterations: 3

| Failure type | Restart point | Token cost |
|-------------|---------------|------------|
| lint error | Direct fix only | ~50 |
| Build failure | Reverse trace only | ~70 |
| sim FAIL | Restart from sim S2 | ~150 |
| Design flaw | Full restart | ~500 |

After max reached: report to user + await approval
Output: "[Loop N/3] {failure type} -> {restart point}"
```

---

## Check: Tool-based Verification (after code)

> Pure tools only. No scenario judgment.

### Check 1: Pre-commit Hooks
- Ruff: Python linter/formatter
- check-ast: AST verification
- Custom Rules: patterns.json-based hardcoding detection

### Check 2: GitHub Actions
- Claude Code Action - AI code review
- Impact analysis
- Security scan (Bandit)

### Check 3: E2E Tests
- API contract verification + internal implementation hardcoding detection

### 3-layer defense

| Layer | Component | Timing | Bypassable |
|-------|-----------|--------|------------|
| Layer 1 | Check 1 (pre-commit) | git commit | Yes (--no-verify) |
| Layer 2 | Check 2 (GitHub Actions) | PR creation | No (CI enforced) |
| Layer 3 | Check 3 (E2E) | PR creation | No (CI enforced) |

---

## Pattern System

> Details: rules/pattern-system.md

3-phase flow: Accumulate -> Trigger -> Analyze+Update

- **Phase 1 (Accumulate)**: When user corrects/rejects/decides -> immediately save to patterns
- **Phase 2 (Trigger)**: Positive expression detected -> trigger analysis
- **Phase 3 (Analyze)**: Extract patterns -> update project-specific pattern file

Pattern types: correction, principle, rejection, decision.
frequency 3+ -> auto-escalate severity.

---

## Related Files

| File | Purpose |
|------|---------|
| `state/patterns.json` | Pattern DB |
| `state/routing.json` | Debate patterns + routing |
| `skills/sim/SKILL.md` | /sim scenario skill |
| `rules/pattern-system.md` | Pattern accumulation system |

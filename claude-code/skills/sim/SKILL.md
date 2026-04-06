---
name: sim
description: Long-term failure simulation - Trace completed code under "3 months + 10x scale" to find breaking points, identify root causes, fix and re-verify
user-invocable: true
---

# /sim - Long-term Failure Simulation

> "Run a long-term simulation, check for issues and improvements, fix them, and summarize."
> This single sentence activates the 3-stage failure simulation loop.

## Position in the System

```
[MID+ risk change]
Research -> DMAD (pre-code debate) -> Implementation spec -> Code -> Self-verify -> sim deep (post-code, here)

[Manual invocation]
/sim -> Can run anytime (regardless of file count or code stage)
```

### Role Separation from DMAD

| Aspect | DMAD (pre-code) | /sim (post-code) |
|--------|-----------------|-------------------|
| Target | Design proposal (no code yet) | Completed code (actual files) |
| Method | DMAD Q&A (Designer vs User) | Failure simulation (trace code for breaking points) |
| Questions | Simpler way? Clash with existing? Dangerous assumption? | Where does it break at 3 months + 10x? Root cause? |
| Nature | Direction verification (should we build this?) | Implementation verification (does what we built survive?) |

## Academic Basis

| Technique | Source | Application |
|-----------|--------|-------------|
| Chain-of-Verification (CoVe) | Meta, arxiv:2309.11495 | S2: Independent verification that found issues actually occur |
| Reflexion | NeurIPS 2023, arxiv:2303.11366 | S3: Fix -> re-simulate loop |
| Intrinsic Self-Critique | Google DeepMind 2025, arxiv:2512.24103 | S1: Self-critique during simulation reasoning |

## Auto-trigger

| Condition | Action |
|-----------|--------|
| MID+ risk change completed | Auto-run after code + self-verify |
| `/sim` direct invocation | Full pipeline execution |
| "simulation", "long-term test" | Suggest /sim |

### Skip conditions
- Simple bug fix (1-2 files, LOW risk)
- Style/format-only changes
- Documentation/test-only changes

---

## 3-Stage Failure Simulation

### S1: Failure Simulation (trace the code)

Read the changed code, set a "3 months + 10x scale" scenario, and trace code line by line to find breaking points.

```
[S1] Failure Simulation

[Preparation] Read changed files + dependency files (no guessing)

[Scenario] "3 months later, users/data 10x"
  - This function receives this request
  - This variable becomes this value
  - Here, this condition fails and breaks

[Tracking targets]
  - Hardcoded values (extensions, model names, paths, encoding)
  - Dependency changes (API versions, libraries, file formats)
  - Scale limits (memory, processing time, concurrent connections)
  - Environment differences (OS, encoding, permissions)
  - Irreversible operations (deletes, external API calls with side effects)
  - Existing code collision: new raise/return caught by existing except/if in same function

[Priority tagging] -- tag each finding immediately
  [P0] Blocker - security breach, data loss, crash, irreversible damage
  [P1] Must-fix - functional defect, resource leak, data inconsistency
  [P2] Improvement - edge case, style, non-critical optimization

[Completion criteria grading]
  If implementation spec has completion criteria:
  | # | Criterion | Scenario | Result | Evidence |
  Grade each criterion as PASS/FAIL with specific evidence
```

**Rules:**
- Must Read actual code before starting simulation
- "Could break" (abstract) forbidden -> "At file:line N, with this input, it breaks" (specific)
- Show the code-tracing process (function call order, variable value changes)

---

### S2: Root Cause Search (why it breaks + same type everywhere)

Identify root cause of S1 findings, then search entire codebase for same pattern type.

```
[S2] Root Cause

[Root cause analysis]
  - Surface cause of breaking point: {what broke}
  - Root cause search loop:
      Candidate cause found ->
      "To fix this, must something else be fixed first?"
        -> Yes: Not root cause yet. Read lower-layer code/config, continue
        -> No:  This is the fix location. Stop searching
  - Does this cause exist elsewhere? -> grep/search entire codebase

[CoVe Verification]
  Step 1: Generate verification questions: "Does this issue actually occur?"
  Step 2: Answer independently without seeing findings (bias prevention)
  Step 3: Only include CoVe-verified items in final results

[Output]
  | # | Break location | Root cause | Same type N found | Priority |
```

**Rules:**
- Don't stop at surface cause -> loop "must something else be fixed first?" down to lowest layer
- Exclude CoVe verification failures from report
- "Probably" forbidden -> state only confirmed findings

---

### S3: Fix + Confirmation Simulation (max 2 loop iterations)

Fix discovered issues and re-run S1 simulation on the fixed code.

```
[S3] Fix + Confirm

[Fix location verification] Required before writing code
  S2 root cause location: {file:line or layer}
  S3 fix location:        {file:line or layer}
  -> Mismatch: fix forbidden, re-search S2
  -> fallback pattern (if X is None: return default_X) forbidden
     Only direct root cause fix allowed

[Fix]
  - Fix S2 root cause location directly (no other-layer fixes)
  - Fix all same-type instances at once
  - Priority order: P0 -> P1 -> P2 (P2 at user discretion)
  | # | Target | Before | After | Rationale |

[Confirmation simulation] Re-run S1 once
  - Re-simulate same scenario with fixed code
  - Verify fix doesn't introduce new issues
  - Regression check: verify pre-fix functionality still works after fix
    -> Trace dependent function/module call paths outside fix scope

[Post-fix commit] git commit required
  -> Format: "[sim] {file}:{line} {fix summary one line}"
  -> Example: "[sim] api.py:42 fix ffprobe order - CoVe verified"
  -> Multiple files: per-file commit or bundled (judgment call)

[Result branch]
  -> Pass: End -> output + pattern record
  -> Fail: Report to user + await approval -> switch to debugging mode
```

**Rules:**
- Simulation loop max 2 iterations (S1 -> S2 -> S3 -> confirm S1)
- After 2nd failure, AI does not keep fixing alone -> user approval required
- After user approval, switch to debugging mode
- [Required] git commit after S3 fix -> ensure traceability

---

## Output Format

```
================================================================
[/sim Failure Simulation Results]
================================================================

[Target] {change summary}

[S1 Simulation]
  Scenario: 3 months + 10x scale
  Files read: N
  Trace path: FunctionA -> FunctionB -> breaks here

[Completion Criteria Grading]
  | # | Criterion | Result | Evidence |
  (If implementation spec has completion criteria)

[S2 Root Cause]
  | # | Break location | Root cause | Same type | Priority |
  (CoVe-verified items only)

[S3 Fix]
  | # | Target | Before | After | Rationale |

[Confirmation Simulation] Pass / Fail (details if fail)

[Pattern Record]
  - New pattern -> add to patterns.json: {if any}
  - Existing pattern variant -> update: {if any}
  - No record needed: {if one-time}

[Summary] OK / WARN / FAIL (user approval needed)
================================================================
```

## Quality Rules

- [Required] Only start simulation after actually reading files
- [Required] Show code-tracing process (transparent reasoning)
- [Required] Exclude CoVe verification failures from report
- [Required] "Probably", "might" forbidden - state only confirmed findings
- [Required] After 2 loop failures, request user approval
- [Forbidden] Simulating from reasoning alone without reading files
- [Forbidden] Surface patch only, ignoring root cause
- [Forbidden] Fixing one instance without searching for same type

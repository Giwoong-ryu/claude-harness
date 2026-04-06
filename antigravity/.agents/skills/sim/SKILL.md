---
name: sim
description: Long-term failure simulation engine - 6-stage pipeline predicting future risks on /sim invocation.
---

# /sim - Scenario Simulation Engine

"Code that runs is just the start. Code that survives is skill."

## 6-Stage Simulation Pipeline

1. **Anchoring (Reality Lock)**: Read actually modified code files and draw dependency graph. (No guessing)
2. **Fail Simulation (S1)**: Generate specific failure scenarios under "3 months + 10x scale". Tag each finding with priority: [P0] Blocker, [P1] Must-fix, [P2] Improvement. Check for existing code collision (new raise/return caught by existing except/if). Audit irreversible operations and external API calls.
3. **Root Cause Analysis (S2)**: Analyze root causes of S1 findings from system architecture perspective. Loop: "Must something else be fixed first?" -> down to lowest layer.
4. **Correction & Verification (S3)**: Fix strategy with location verification (S2 root cause = S3 fix location). Re-verify under "3 months + 10x" scenario. Fallback patterns forbidden. Fix priority: P0 -> P1 -> P2.
5. **Completion Criteria Grading**: If implementation spec exists, grade each completion criterion as PASS/FAIL with evidence.
6. **Report Artifact**: Generate `sim_report.md` in [Target/Stage/Scenario/Verdict] format.
7. **Pattern Loop**: Decide whether to record key lessons from this simulation.

## Personas
- **Architect**: Finds structural vulnerabilities.
- **Hacker**: Forces exception scenarios and attacks.
- **Operator**: Critiques from long-term maintenance perspective.

---
description: sim - S1->S2->S3 long-term failure simulation and future risk prediction
---

# Sim Deep (Antigravity Version)

// turbo-all

This workflow goes beyond verifying that code works -- it tests **potential future failures** through staged scenarios.

## Execution Procedure

### Stage 1: S1 - Failure Simulation (Fail Sim)
- Under "3 months + 10x scale" scenario, generate specific failure scenarios for current code.
- Identify most critical breaking points: data bottlenecks, memory leaks, dependency conflicts.
- Tag each finding: [P0] Blocker (security/data loss/crash), [P1] Must-fix (functional/resource), [P2] Improvement (edge case/style).
- Check existing code collision: new raise/return caught by existing except/if in same function.
- Audit irreversible operations and external API calls with side effects.
- If implementation spec has completion criteria, grade each as PASS/FAIL.

### Stage 2: S2 - Root Cause Search (Root Cause)
- Trace root cause of S1 failures.
- Go beyond simple code fixes to analyze architectural flaws and scalability limits.
- Loop: "Must something else be fixed first?" -> down to lowest fixable layer.
- Search entire codebase for same pattern type.

### Stage 3: S3 - Fix and Verify (Verify)
- Fix location verification: S2 root cause location must match S3 fix location (mismatch = fix forbidden).
- Fallback patterns forbidden (if X is None: return default) -- fix root cause directly.
- Fix priority: P0 -> P1 -> P2 (P2 at user discretion).
- Verify fixed code survives "3 months + 10x scale" in final simulation.
- Regression check: pre-fix functionality still works after fix.

## Usage
- Auto-suggested after MID+ risk changes, or when user issues `/sim` command.
- Results provided as table: [Target/Duration/Scenario/Verdict(OK, WARN, FAIL)] with P0/P1/P2 tags.

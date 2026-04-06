# ez-harness

A verification harness for AI-generated code. Catches bugs before they happen.

Works with **Claude Code** and **Antigravity**.

**Core flow: Research -> Plan -> Feasibility Review -> Refinement -> Code -> Verification**

The harness forces AI to research first, plan with implementation specs, debate the design from two opposing perspectives, then verify completed code against "3 months + 10x scale" failure scenarios -- all before deployment.

---

## Why

AI code generation has recurring failure patterns:

- Explaining code from memory without reading files (hallucination)
- Fixing symptoms only, leaving root cause untouched (surface patch)
- Writing code without design review, discovering structural issues late
- Fixing one bug while the same type recurs in other files
- Adding fallback at symptom location instead of fixing root cause (new bugs)

This harness structurally blocks these patterns.

Reference: [CodeRabbit 2026 Report](https://www.coderabbit.ai/blog/ai-code-review-stats) measured AI-generated code at 1.7x total issues, 2.74x security vulnerabilities, and 2x error handling gaps compared to human code.

---

## Components

| Stage | Name | Role | Trigger |
|-------|------|------|---------|
| 0 | **Reverse Trace** | Confirm bug root cause before fix | Error/bug keyword detected |
| 1 | **GATE** | Load patterns, output related warnings | Once before code |
| 2 | **Risk Assessment** | Score 8 risk factors -> LOW/MID/HIGH | Before code |
| 3 | **Research** | WebSearch/Context7 for latest info | MID+ risk |
| 4 | **DMAD Debate** | Designer vs User perspective Q&A | MID+ risk |
| 5 | **Implementation Spec** | File-level function/change scope + completion criteria | After DMAD |
| 6 | **sim** | 3 months + 10x failure simulation with P0/P1/P2 grading | MID+ risk, after code |
| 7 | **smartLoop** | Restart from failure-specific minimal point | sim/Check failure |

### Risk Assessment (8 factors)

Instead of simple file count, risk is scored across 8 factors:

| Factor | Condition | Score |
|--------|-----------|-------|
| File count | 3-5: +1, 6-9: +2, 10+: +3 | 0-3 |
| New dependency | New library/package | +1 |
| DB/Schema | Migration, table changes | +2 |
| Auth/Security | Auth, permissions, tokens | +2 |
| API contract | Endpoint add/change | +1 |
| External integration | 3rd party API, webhook | +1 |
| New user-facing feature | New UI, new workflow | +1 |
| Existing code deletion | File delete, function replace | +1 |

**0-1 = LOW** (code directly), **2-3 = MID** (research + debate + sim), **4+ = HIGH** (full pipeline with 2 rounds)

### Research

Before DMAD debate, AI investigates latest libraries, best practices, and similar implementations using WebSearch/Context7. Results are saved to `research.md` for reference during implementation.

### DMAD Debate

Two opposing perspectives review the design before any code is written:

**Designer (forward):** Simpler way? Clash with existing? Most dangerous assumption? Code duplication? Scattered code?

**User (reverse):** Can first-timer use it? Natural behavior? Self-recoverable? Silent error swallowing?

Key rules:
- Read all target files before debate starts
- Cite code as `filename:line:content` -- claims without citations forbidden
- No full agreement between roles; defend with evidence

Why the citation rule matters: [`docs/dmad-false-positive-analysis.md`](claude-code/docs/dmad-false-positive-analysis.md)

### Implementation Spec

After DMAD consensus, a spec is written before coding:
- File-level function/change scope with research references
- Completion criteria (PASS/FAIL gradable)
- sim uses these criteria for grading

### sim (Long-term Failure Simulation)

The biggest differentiator. Catches bugs that haven't happened yet.

```
S1. "3 months + 10x scale" simulation - trace code line by line
    - Tag findings: [P0] Blocker, [P1] Must-fix, [P2] Improvement
    - Check for existing code collision (new raise/return caught by existing except/if)
    - Grade against completion criteria from implementation spec
S2. Root cause loop - "Must something else be fixed first?" -> down to lowest layer
S3. Fix location verification: S2 root cause = S3 fix location (mismatch = fix forbidden)
    - fallback pattern forbidden: no symptom bypass, root cause fix only
```

`/sim` can be invoked manually anytime.

### smartLoop

On failure, restarts from the minimal point instead of full re-run:

| Failure type | Restart point | Token cost |
|-------------|---------------|------------|
| lint error | Direct fix only | ~50 |
| Build failure | Reverse trace only | ~70 |
| sim FAIL | sim S2 restart | ~150 |
| Design flaw | Full restart | ~500 |

Max 3 iterations. Reports to user after max.

---

## Hooks (Optional Auto-protection)

The `hooks/` folder contains two Python scripts that provide automatic protection:

| Hook | Event | Function |
|------|-------|----------|
| `gate-check.py` | PreToolUse (Write/Edit) | Blocks API key hardcoding, warns on repeated mistake patterns |
| `smart_gate.py` | UserPromptSubmit | Injects relevant pattern warnings per message |

These are **optional** -- the harness works without them. The hooks add automated guardrails.

Install via `install.sh` (Mac/Linux) or `install.ps1` (Windows) which registers hooks in `~/.claude/settings.json`.

---

## File Structure

```
ez-harness/
├── claude-code/                         # Claude Code version
│   ├── CLAUDE.md                        # Entry point (risk-based verification flow)
│   ├── hooks/
│   │   ├── gate-check.py               # PreToolUse: API key block + pattern warning
│   │   └── smart_gate.py               # UserPromptSubmit: relevant pattern injection
│   ├── state/
│   │   ├── routing.json                 # DMAD roles + smartLoop + triggers
│   │   └── patterns.json               # Pattern DB (grows with use)
│   ├── rules/
│   │   ├── eazycheck.md                # GATE + Risk + Research + DMAD + sim + Check
│   │   └── pattern-system.md            # Pattern accumulation (3-Phase)
│   ├── skills/
│   │   └── sim/SKILL.md                 # /sim failure simulation procedure
│   └── docs/
│       └── dmad-false-positive-analysis.md
│
├── antigravity/                         # Antigravity version
│   ├── RULES.md                         # Global rules (reverse trace + GATE + DMAD + sim + smartLoop)
│   └── .agents/
│       ├── workflows/
│       │   └── sim.md                   # /sim workflow (S1->S2->S3)
│       └── skills/
│           └── sim/SKILL.md             # sim auto-detect skill
│
├── install.sh                           # Mac/Linux installer
├── install.ps1                          # Windows installer
└── ez-harness.html                      # Landing page
```

---

## Installation

### Quick Install (recommended)

**Mac/Linux:**
```bash
git clone https://github.com/ez-claude/ez-harness.git
cd ez-harness
chmod +x install.sh
./install.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/ez-claude/ez-harness.git
cd ez-harness
.\install.ps1
```

The installer:
1. Copies hooks, skills, and patterns to `~/.claude/`
2. Merges CLAUDE.md rules into your existing config
3. Registers hooks in `~/.claude/settings.json`

### Manual Install

#### Core only (reverse trace + verification flow)

Merge `claude-code/CLAUDE.md` into `~/.claude/CLAUDE.md`.

#### Full

```bash
cp -r claude-code/rules/ ~/.claude/rules/
cp -r claude-code/skills/ ~/.claude/skills/
cp -r claude-code/state/ ~/.claude/state/
cp -r claude-code/hooks/ ~/.claude/hooks/
# CLAUDE.md: merge or replace
```

### Antigravity

```bash
cp antigravity/RULES.md {project-root}/RULES.md
cp -r antigravity/.agents/ {project-root}/.agents/
```

Adjust paths in rule files to match your environment.

---

## Changes from v5 to v6.1

| Area | v5 | v6.1 |
|------|-----|------|
| Branch criteria | File count (1-2/3-5/6+) | Risk score (8 factors, 0-1/2-3/4+) |
| Research | None | MID+ risk: WebSearch/Context7 before DMAD |
| Implementation spec | None | After DMAD: file/function scope + completion criteria |
| DMAD Designer | 4 questions | 5 questions (+colocation check Q5) |
| DMAD User | 3 questions | 4 questions (+silent error swallowing Q4) |
| Self-verification | None | Post-code: predicted vs actual risk comparison |
| sim findings | Severity listed | P0/P1/P2 priority tags |
| sim grading | No criteria | Grades against completion criteria from spec |
| Hooks | None | gate-check.py + smart_gate.py (optional) |
| Installer | None | install.sh + install.ps1 |

---

## Limitations

- Built from operating a single project (Python/FastAPI). Other stacks may need adjustment.
- DMAD and sim require AI to Read actual files. Effectiveness decreases when context window is insufficient.
- More rules = more token cost. If the full set is too heavy, use the "Core only" install option.
- DMAD domain knowledge false positives still occur. ([Details](claude-code/docs/dmad-false-positive-analysis.md))

---

## References

- [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)
- [Martin Fowler - Exploring Generative AI](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Toss Tech - Harness for Team Productivity](https://toss.tech/article/harness-for-team-productivity)
- [CodeRabbit AI Code Review Stats 2026](https://www.coderabbit.ai/blog/ai-code-review-stats)

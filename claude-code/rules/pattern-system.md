# Pattern Accumulation System

> AI accumulates user corrections, principles, rejections, and decisions as patterns.
> These patterns improve future code generation quality within the same project.

---

## Purpose-based Pattern Separation

**Same user, different purpose = different patterns.** Don't put everything in one file.

```
memory/patterns/
├── web-api-project.json     <- Web API development patterns
├── mobile-app.json          <- Mobile app patterns
├── data-pipeline.json       <- Data pipeline patterns
└── _common.json             <- Purpose-agnostic common (always loaded)
```

**File naming:** Use keywords AI can quickly find via Glob/search.

---

## Session Start: Load Procedure

```
[1] Read: memory/patterns/INDEX.json -> list all pattern files
[2] Task identification: match keywords + working_dir + active_files
    - 2+ matches -> load that file
[3] _common.json always loaded (always_load=true)
[4] No matching file -> create new one (use purpose keywords for filename)
[5] Register new file in INDEX.json
```

---

## 3-Phase Flow

```
[Phase 1: Accumulate] User corrects/sets principle/rejects/decides -> save immediately
     |
[Phase 2: Trigger] Positive expression detected -> trigger analysis
     |
[Phase 3: Analyze+Update] Analyze accumulated items -> move to purpose-specific pattern file
```

---

## Phase 1: Accumulate (immediate save)

When the user does any of the following, **immediately** save to memory/patterns/:

### 4 accumulation types

| Type | Detection | Content |
|------|-----------|---------|
| **Correction** | User requests specific change to AI output | ai_did + user_said + correct_answer |
| **Principle** | Rule/standard that should apply going forward | principle + severity (critical/high/medium) |
| **Rejection** | Explicit negation of AI suggestion | rejected + reason |
| **Decision** | One option chosen from multiple | what + why + alternatives + reverse_when |

### Save vs Don't Save

| Type | Save (pattern) | Don't save |
|------|---------------|------------|
| **Correction** | "Change this to that" (AI output fix) | "Explain more" (additional request) |
| **Principle** | "Always do X", "Never do Y" (recurring) | "Just this once" (one-time) |
| **Rejection** | "That's wrong", "Don't need it" (explicit no) | "Any alternatives?" (exploring) |
| **Decision** | "Let's go with B" (confirmed) | "Which is better?" (question) |

### Core distinction

```
[1] "Just this time" vs "From now on"
    -> One-time = don't save
    -> Recurring rule = save as principle

[2] "Question" vs "Instruction"
    -> Question/exploration = don't save
    -> Clear instruction/confirmation = save

[3] Same feedback repeated
    -> Increment frequency count
    -> frequency 3+ -> auto-escalate severity
```

---

## Phase 2: Trigger = Positive Expression

| Positive signal | Examples |
|----------------|---------|
| **Explicit approval** | "Good", "Fine", "OK", "That works", "Done" |
| **Partial approval** | "Good but...", "This part is right" |
| **Completion mention** | "80% there", "Almost done", "Just fix this part" |
| **Topic transition** | "OK, now let's..." (satisfied with previous) |

**Negative expressions are NOT triggers** -> continue Phase 1 accumulation only.

---

## Phase 3: Checkpoint Save + Analysis

On positive trigger:

```
[1] Create checkpoint
    - Record satisfaction level (80%, 90%, 100%)
    - Positive: what user liked
    - Gaps: remaining issues

[2] Compare with previous checkpoint (if exists)
    - Previous(80%) -> Current(90%): what changed?
    - The improved 10% = what user values most

[3] Extract patterns
    - Improvement items between checkpoints -> user priorities
    - Repeated corrections -> escalate severity
    - New principles -> add to principles

[4] Update purpose-specific pattern file
    - Add checkpoint to checkpoints[]
    - Update corrections/principles/preferences
    - Add decisions[] if technical/structural choices were made

[5] 1-line report: "[PATTERN] Checkpoint saved (80%->90%, +N patterns)"
```

### When no accumulated feedback exists

Even if positive expression is detected, don't run Phase 3 if there are no corrections/principles/rejections accumulated. Simple agreement has no patterns to save.

---

## Storage Format

```json
{
  "_meta": { "purpose": "Web API project", "created": "2026-03-14" },
  "checkpoints": [
    { "id": "CP001", "satisfaction": "80%", "positive": "...", "gaps": "...", "diff_from_prev": "..." }
  ],
  "corrections": [{ "ai_did": "...", "user_said": "...", "correct_answer": "...", "pattern": "..." }],
  "decisions": [{
    "id": "D001",
    "date": "2026-03-14",
    "what": "What was decided",
    "why": "Why this was chosen",
    "alternatives": ["Considered but rejected alternatives"],
    "reverse_when": "Condition to reverse this decision"
  }],
  "principles": [{ "principle": "...", "severity": "critical/high/medium" }],
  "patterns_discovered": ["Accuracy > convenience", "Completeness matters"]
}
```

---

## _common.json (purpose-agnostic)

```json
{
  "communication": ["When uncertain, say so and investigate", "Present options"],
  "workflow": ["Sync all related files when modifying", "Prefer existing tools"],
  "anti_patterns": ["Guessing confidently", "Surface-level tips as solutions"]
}
```

---

## Pattern Usage (new session)

- Session start: INDEX.json -> load matching files
- principles with severity=critical -> always apply
- corrections with frequency 2+ -> proactively prevent same mistakes
- rejections -> pre-filter that content type

---

## File Management (monthly)

- checkpoints over 20 -> archive old ones to `_archive/`
- corrections with frequency 5+ already reflected in system files -> delete (no duplication)
- Purpose files unused for 6 months -> move to `_archive/`

"""
Pattern Trigger Hook - UserPromptSubmit
Detects positive/decision expressions in user messages and notifies AI to run Phase 3.
Runs on every message but only does keyword matching (<0.1s).
Supports both Korean and English patterns.
"""
import json
import re
import sys

# Read hook input from stdin
hook_input = json.loads(sys.stdin.read())
user_message = hook_input.get("prompt", "")

# Positive trigger patterns (regex)
POSITIVE_PATTERNS = [
    # Korean
    r"좋[다아]",           # good
    r"좋[은는]데",          # good but...
    r"괜찮[다아은]",        # fine
    r"됐[어다]",           # done
    r"끝이[야다]",          # it's done
    r"이거[면로]?\s*[돼되]",  # this works
    r"\d{2,3}\s*%",        # 80%, 90%, 95%
    r"거의\s*다\s*됐",      # almost done
    r"이\s*부분만\s*고치면",  # just fix this part
    r"이건\s*맞[아다는]",    # this is right
    r"그럼\s*이제",         # OK, now... (topic transition)
    r"다음[은는으]",        # next (topic transition)
    # English
    r"\bgood\b",
    r"\bnice\b",
    r"\bperfect\b",
    r"\blooks\s+good\b",
    r"\bthat\s+works\b",
    r"\bdone\b",
    r"\bgreat\b",
    r"[OKok]{2}",
]

# Decision trigger patterns (explicit technical/structural choices)
DECISION_PATTERNS = [
    # Korean
    r"[으]?로\s*(하자|가자|갈게|결정)",   # let's go with ~
    r"이걸로\s*(하자|해|할게|가자)",       # let's use this
    r"(으)?로\s*확정",                    # confirmed as ~
    r"(채택|선택|결정)\s*(하자|해|했어)",   # adopt/select/decide
    r"말고\s*\S+[으]?로\s*(하자|해|할게|가자|쓰자)",  # not A, use B
    r"대신\s*.+쓰자",                     # instead of A, use B
    r"안\s*쓰고\s*.+쓰자",               # don't use A, use B
    # English
    r"\blet'?s\s+go\s+with\b",
    r"\bI'?ll\s+take\b",
    r"\bdecided\b",
    r"\bconfirmed\b",
]

# Exclude patterns (false positive prevention) - questions/negative context
EXCLUDE_PATTERNS = [
    # Korean
    r"좋[다아은]\s*[?？]",   # "Is it good?" question
    r"이게\s*좋[아은]",     # "Is this good?" comparison
    r"뭐가\s*좋",          # "What's better?"
    r"어떤게\s*좋",        # "Which is better?"
    r"다음[은는으]\s*뭐",   # "What's next?" question
    r"다음[은는으]\s*어떤",  # "What kind is next?" question
    r"\d{2,3}\s*%\s*(를|의|가|은|는)",  # "80% of the code" (description, not approval)
    # English
    r"\bgood\s*\?",
    r"\bis\s+that\s+good\b",
    r"\blooks\s+good\s*\?",
]


def check_trigger(message: str) -> dict:
    """Return detection result: {triggered: bool, type: "positive"|"decision"|None}"""
    if not message or len(message) < 2:
        return {"triggered": False, "type": None}
    # Check exclude patterns first
    for pattern in EXCLUDE_PATTERNS:
        if re.search(pattern, message, re.IGNORECASE):
            return {"triggered": False, "type": None}
    # Check decision patterns first (more specific than positive)
    for pattern in DECISION_PATTERNS:
        if re.search(pattern, message, re.IGNORECASE):
            return {"triggered": True, "type": "decision"}
    # Check positive patterns
    for pattern in POSITIVE_PATTERNS:
        if re.search(pattern, message, re.IGNORECASE):
            return {"triggered": True, "type": "positive"}
    return {"triggered": False, "type": None}


trigger = check_trigger(user_message)

if trigger["triggered"]:
    if trigger["type"] == "decision":
        # User explicitly used decision expression (rare case)
        result = {
            "result": "warn",
            "message": (
                "[APPROVAL TRIGGER] Decision/approval expression detected. "
                "If a technical decision/proposal was made in the previous exchange, "
                "record it in decisions[] (what/why/alternatives/reverse_when). "
                "If general feedback, run Phase 3. Details: docs/pattern-system.md"
            ),
        }
    else:
        # Positive expression = could be approval or simple feedback -> AI decides from context
        result = {
            "result": "warn",
            "message": (
                "[APPROVAL TRIGGER] Positive expression detected. "
                "(1) If AI proposed a technical/structural/directional choice in previous exchange "
                "-> record in decisions[] (what/why/alternatives/reverse_when). "
                "(2) If accumulated feedback exists -> run Phase 3. "
                "Details: docs/pattern-system.md"
            ),
        }
else:
    result = {"result": "pass"}

print(json.dumps(result))

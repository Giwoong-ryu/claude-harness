"""
PreCompact Hook - Force Phase 3 trigger
Fires just before context compression. If _buffer.json has unprocessed items,
forces AI to run Phase 3 (analyze + move to purpose-specific pattern file).
Phase 1 saves immediately, so no "emergency save" needed - only analysis + move.

Buffer path resolution: finds the matching project folder under ~/.claude/projects/
based on current working directory, then looks for memory/patterns/_buffer.json.
"""
import json
import sys
import os
import re
from datetime import datetime

# Read hook input from stdin
hook_input = json.loads(sys.stdin.read())
trigger = hook_input.get("trigger", "unknown")  # "auto" or "manual"

# Log
log_dir = os.path.expanduser("~/.claude/hooks/logs")
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, "precompact_test.log")

with open(log_file, "a", encoding="utf-8") as f:
    f.write(f"[{datetime.now().isoformat()}] PreCompact fired | trigger={trigger}\n")


def find_buffer_path():
    """
    Find _buffer.json by matching current working directory to a project folder
    under ~/.claude/projects/. Returns the path if found, None otherwise.
    """
    projects_dir = os.path.expanduser("~/.claude/projects")
    if not os.path.isdir(projects_dir):
        return None

    cwd = os.getcwd().replace("\\", "/").lower()

    # Claude Code encodes project paths as folder names with dashes replacing separators
    # e.g. /home/user/my-project -> home-user-my-project
    # or C:\Users\user\Desktop\gpt -> c--Users-user-Desktop-gpt
    best_match = None
    best_length = 0

    for folder_name in os.listdir(projects_dir):
        folder_path = os.path.join(projects_dir, folder_name)
        if not os.path.isdir(folder_path):
            continue

        # Decode the folder name back to a path for matching
        # Replace leading drive letter pattern (e.g., "c--") and dashes
        decoded = folder_name.replace("--", ":/").replace("-", "/").lower()

        if cwd.startswith(decoded) or decoded.startswith(cwd):
            match_len = min(len(cwd), len(decoded))
            if match_len > best_length:
                best_length = match_len
                best_match = folder_path

    if not best_match:
        return None

    buffer_path = os.path.join(best_match, "memory", "patterns", "_buffer.json")
    if os.path.exists(buffer_path):
        return buffer_path

    return None


# Check _buffer.json existence + item count
buffer_path = find_buffer_path()
has_items = False
item_count = 0

if buffer_path and os.path.exists(buffer_path):
    try:
        with open(buffer_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            items = data.get("items", [])
            item_count = len(items)
            has_items = item_count > 0
    except (json.JSONDecodeError, KeyError):
        pass

messages = []

if has_items:
    messages.append(
        f"[PATTERN] _buffer.json has {item_count} unprocessed items. "
        "Run Phase 3: move _buffer items to pattern files, then clear buffer."
    )

# Work-log auto-save instruction (always)
messages.append(
    "[WORK-LOG] Auto-save before compression. "
    "Save this session's pivots/improvements/insights to memory/work-logs/. "
    "If no changes occurred, skip. Do not ask the user."
)

if messages:
    result = {
        "result": "warn",
        "message": " | ".join(messages),
    }
else:
    result = {"result": "pass"}

print(json.dumps(result))

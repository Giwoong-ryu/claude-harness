#!/usr/bin/env python3
"""
EazyCheck Gate - 코드 파일 수정 시 자동 검증 (PreToolUse hook)

토큰 사용: 0 (Python 스크립트로 동작, AI 호출 없음)

기능:
1. API 키 하드코딩 차단 (deny)
2. 반복 실수 패턴 경고 (ask_user)

Write/Edit/MultiEdit 도구 호출 시 자동 실행.
state/, memory/, .claude/ 등 시스템 파일은 자동 통과.
"""

import json
import sys
import os
import re

# 시스템 파일은 무조건 통과
SAFE_PATHS = [
    "state/", "state\\",
    "memory/", "memory\\",
    ".claude/", ".claude\\",
    "session.json", "patterns.json", "versions.json",
    "/tmp/", "\\tmp\\", "temp_",
]

# 검사 대상 확장자
CODE_EXTENSIONS = {".py", ".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte"}

# API 키 패턴 (차단)
DANGER_PATTERNS = [
    (r"AIzaSy[a-zA-Z0-9_-]{33}", "Google API Key"),
    (r"sk-[a-zA-Z0-9]{20,}", "OpenAI API Key"),
    (r"ghp_[a-zA-Z0-9]{36}", "GitHub Personal Token"),
    (r"gho_[a-zA-Z0-9]{36}", "GitHub OAuth Token"),
    (r"AKIA[A-Z0-9]{16}", "AWS Access Key"),
]


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    if tool_name not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    file_path = tool_input.get("file_path", "")
    if not file_path:
        sys.exit(0)

    # 시스템 파일 통과
    for safe in SAFE_PATHS:
        if safe in file_path:
            sys.exit(0)

    # 코드 파일이 아니면 통과
    _, ext = os.path.splitext(file_path)
    if ext.lower() not in CODE_EXTENSIONS:
        sys.exit(0)

    # 수정 내용 추출
    new_content = ""
    if tool_name == "Write":
        new_content = tool_input.get("content", "")
    elif tool_name == "Edit":
        new_content = tool_input.get("new_string", "")
    elif tool_name == "MultiEdit":
        edits = tool_input.get("edits", [])
        new_content = " ".join(e.get("new_string", "") for e in edits)

    # [1] API 키 하드코딩 차단
    for pattern, name in DANGER_PATTERNS:
        if re.search(pattern, new_content):
            json.dump({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": f"[EazyCheck] {name} 하드코딩 감지. os.getenv() 사용 필수."
                }
            }, sys.stdout)
            sys.exit(0)

    # [2] 반복 실수 패턴 경고
    patterns_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "state", "patterns.json")
    if not os.path.exists(patterns_path):
        # 글로벌 경로도 확인
        patterns_path = os.path.expanduser("~/.claude/state/patterns.json")

    if os.path.exists(patterns_path):
        try:
            with open(patterns_path, "r", encoding="utf-8") as f:
                patterns_data = json.load(f)

            freq_val = {"very_high": 5, "critical": 4, "high": 3}

            for mistake in patterns_data.get("claude_mistakes", []):
                freq = mistake.get("frequency", "")
                if freq not in freq_val:
                    continue

                mid = mistake.get("id", "")
                solution = mistake.get("solution", "")

                # 패턴별 트리거 조건
                triggered = False
                if mid == "type-value-incomplete-replacement" and ext in {".ts", ".tsx"}:
                    if any(k in new_content.lower() for k in ["enum", "type ", "interface "]):
                        triggered = True
                elif mid == "outdated-documentation-blindly-followed":
                    if any(k in new_content.lower() for k in ["gemini-", "gpt-4", "gpt-3", "claude-3"]):
                        triggered = True

                if triggered:
                    json.dump({
                        "hookSpecificOutput": {
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "ask_user",
                            "permissionDecisionReason": f"[EazyCheck] 반복 실수 패턴: {mid}. {solution}"
                        }
                    }, sys.stdout)
                    sys.exit(0)

        except (json.JSONDecodeError, KeyError):
            pass

    sys.exit(0)


if __name__ == "__main__":
    main()

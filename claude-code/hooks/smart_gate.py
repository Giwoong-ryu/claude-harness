#!/usr/bin/env python3
"""
EazyCheck Smart Gate - 사용자 메시지에서 관련 패턴만 선별 경고 (UserPromptSubmit hook)

토큰 사용: 매칭 없으면 0, 매칭 시 ~50-100 토큰 (경고 메시지만)

동작:
1. 사용자 메시지에서 키워드 추출
2. patterns.json의 trigger/id와 매칭
3. 관련 패턴만 경고 주입 (없으면 완전 패스)
"""

import json
import sys
import os

try:
    hook_input = json.loads(sys.stdin.read())
except (json.JSONDecodeError, Exception):
    print(json.dumps({"result": "pass"}))
    sys.exit(0)

user_message = hook_input.get("prompt", "").lower()

if not user_message or len(user_message) < 5:
    print(json.dumps({"result": "pass"}))
    sys.exit(0)

# patterns.json 찾기 (프로젝트 내 → 글로벌)
patterns_path = None
for p in [
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "state", "patterns.json"),
    os.path.expanduser("~/.claude/state/patterns.json"),
]:
    if os.path.exists(p):
        patterns_path = p
        break

if not patterns_path:
    print(json.dumps({"result": "pass"}))
    sys.exit(0)

try:
    with open(patterns_path, "r", encoding="utf-8") as f:
        patterns = json.load(f)
except (json.JSONDecodeError, IOError):
    print(json.dumps({"result": "pass"}))
    sys.exit(0)

# 동의어 확장
SYNONYMS = {
    "보안": ["security", "취약점", "vulnerability"],
    "인증": ["auth", "로그인", "login", "토큰", "token"],
    "데이터베이스": ["db", "database", "디비", "테이블"],
    "에러": ["error", "오류", "버그", "bug", "실패", "fail"],
    "배포": ["deploy", "릴리즈", "release"],
    "모델": ["model", "gemini", "openai", "claude", "gpt"],
}

expanded = user_message
for canonical, aliases in SYNONYMS.items():
    if canonical in user_message:
        expanded += " " + " ".join(aliases)
    for alias in aliases:
        if alias in user_message:
            expanded += " " + canonical
            break

warnings = []

# preventive_patterns 매칭
for p in patterns.get("preventive_patterns", []):
    for t in p.get("trigger", []):
        if t.lower() in expanded:
            solution = p.get("solution", "")
            if isinstance(solution, list):
                solution = ", ".join(solution)
            warnings.append(f"[{p['id']}] {solution}")
            break

# claude_mistakes (high+) 매칭
for m in patterns.get("claude_mistakes", []):
    freq = m.get("frequency", "")
    if freq not in ("very_high", "critical", "high"):
        continue
    id_words = m.get("id", "").replace("-", " ").replace("_", " ").split()
    matched = sum(1 for w in id_words if len(w) > 4 and w in expanded)
    if matched >= 2:
        warnings.append(f"[{m['id']}] {m.get('solution', '')[:80]}")

if warnings:
    msg = "[EazyCheck] 관련 패턴:\n" + "\n".join(f"  - {w}" for w in warnings)
    print(json.dumps({"result": "warn", "message": msg}))
else:
    print(json.dumps({"result": "pass"}))

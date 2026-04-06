#!/bin/bash
# EazyCheck 설치 스크립트 (Mac/Linux)

set -e

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "EazyCheck 설치 시작..."

# 0. Python 확인
PYTHON_CMD=""
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    # python이 실제 Python인지 확인 (Windows Store 리다이렉트 제외)
    if $( python --version &>/dev/null ); then
        PYTHON_CMD="python"
    fi
fi

if [ -z "$PYTHON_CMD" ]; then
    echo "Python이 설치되지 않았습니다."
    echo "https://python.org 에서 Python 3.8 이상을 설치해주세요."
    exit 1
fi
echo "  Python: $PYTHON_CMD ($($PYTHON_CMD --version 2>&1))"

# 1. ~/.claude/ 확인
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "~/.claude/ 폴더가 없습니다. Claude Code를 먼저 설치해주세요."
    exit 1
fi

# 2. 폴더 생성
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/skills/sim"
mkdir -p "$CLAUDE_DIR/state"

# 3. hooks 복사
cp "$SCRIPT_DIR/hooks/gate-check.py" "$CLAUDE_DIR/hooks/eazycheck-gate.py"
cp "$SCRIPT_DIR/hooks/smart_gate.py" "$CLAUDE_DIR/hooks/eazycheck-smart-gate.py"
cp "$SCRIPT_DIR/hooks/pattern_trigger.py" "$CLAUDE_DIR/hooks/eazycheck-pattern-trigger.py"
cp "$SCRIPT_DIR/hooks/precompact_pattern_save.py" "$CLAUDE_DIR/hooks/eazycheck-precompact.py"
echo "  hooks 설치 완료 (4개)"

# 4. skills 복사
SKILLS="sim systematic-debugging writing-plans executing-plans verification-before-completion sequential-thinking confidence-check brainstorming dispatching-parallel-agents subagent-driven-development using-git-worktrees finishing-a-development-branch receiving-code-review requesting-code-review test-driven-development prompt-engineering"
SKILLS_INSTALLED=0
SKILLS_SKIPPED=0

for SKILL_NAME in $SKILLS; do
    SKILL_SRC="$SCRIPT_DIR/skills/$SKILL_NAME/SKILL.md"
    SKILL_DST_DIR="$CLAUDE_DIR/skills/$SKILL_NAME"
    SKILL_DST="$SKILL_DST_DIR/SKILL.md"

    if [ ! -f "$SKILL_SRC" ]; then
        continue
    fi

    mkdir -p "$SKILL_DST_DIR"

    if [ -f "$SKILL_DST" ]; then
        # Existing skill found - save as preset, don't overwrite
        cp "$SKILL_SRC" "$SKILL_DST_DIR/eazycheck-preset.md"
        SKILLS_SKIPPED=$((SKILLS_SKIPPED + 1))
    else
        cp "$SKILL_SRC" "$SKILL_DST"
        SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
    fi
done
echo "  skills: ${SKILLS_INSTALLED}개 설치, ${SKILLS_SKIPPED}개 기존 유지"

# 5. patterns.json 병합 또는 복사
if [ -f "$CLAUDE_DIR/state/patterns.json" ]; then
    echo "  기존 patterns.json 발견 - 백업 후 유지 (새 프리셋은 eazycheck-patterns-preset.json으로 저장)"
    cp "$SCRIPT_DIR/state/patterns.json" "$CLAUDE_DIR/state/eazycheck-patterns-preset.json"
else
    cp "$SCRIPT_DIR/state/patterns.json" "$CLAUDE_DIR/state/patterns.json"
    echo "  patterns.json 설치 완료"
fi

# 6. CLAUDE.md 처리
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    if grep -q "EazyCheck" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
        echo "  CLAUDE.md에 EazyCheck 이미 존재 - 건너뜀"
    else
        echo "" >> "$CLAUDE_DIR/CLAUDE.md"
        cat "$SCRIPT_DIR/CLAUDE.md" >> "$CLAUDE_DIR/CLAUDE.md"
        echo "  CLAUDE.md에 EazyCheck 추가 완료"
    fi
else
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "  CLAUDE.md 설치 완료"
fi

# 7. settings.json에 hooks 등록
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "eazycheck-gate" "$SETTINGS_FILE" 2>/dev/null; then
        echo "  hooks 이미 등록됨 - 건너뜀"
    else
        # Python으로 기존 settings.json에 hooks 안전 추가
        $PYTHON_CMD -c "
import json, sys
with open('$SETTINGS_FILE', 'r') as f:
    settings = json.load(f)
hooks = settings.setdefault('hooks', {})
pre = hooks.setdefault('PreToolUse', [])
pre.append({'matcher': 'Write|Edit|MultiEdit', 'hooks': [{'type': 'command', 'command': '$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-gate.py'}]})
user = hooks.setdefault('UserPromptSubmit', [])
user.append({'matcher': '', 'hooks': [{'type': 'command', 'command': '$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-smart-gate.py'}, {'type': 'command', 'command': '$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-pattern-trigger.py'}]})
compact = hooks.setdefault('PreCompact', [])
compact.append({'matcher': '', 'hooks': [{'type': 'command', 'command': '$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-precompact.py'}]})
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
" 2>/dev/null && echo "  settings.json에 hooks 추가 완료" || {
            echo ""
            echo "  [수동 설정 필요] settings.json에 hooks를 수동으로 추가해주세요."
            echo "  상세: README.md 참조"
        }
    fi
else
    # settings.json 새로 생성
    cat > "$SETTINGS_FILE" << SETTINGS_EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-gate.py"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-smart-gate.py"
          },
          {
            "type": "command",
            "command": "$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-pattern-trigger.py"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$PYTHON_CMD $CLAUDE_DIR/hooks/eazycheck-precompact.py"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
    echo "  settings.json 생성 + hooks 등록 완료"
fi

echo ""
echo "EazyCheck 설치 완료!"
echo ""
echo "동작 확인:"
echo "  - API 키를 코드에 쓰면 자동 차단됩니다"
echo "  - 과거 실수와 비슷한 작업 시 자동 경고합니다"
echo "  - 긍정/결정 표현 감지 시 패턴을 자동 축적합니다"
echo "  - 컨텍스트 압축 전 미처리 패턴을 보존합니다"
echo "  - /sim 으로 완성된 코드의 미래 문제를 탐지합니다"

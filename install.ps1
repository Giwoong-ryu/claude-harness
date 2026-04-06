# EazyCheck 설치 스크립트 (Windows PowerShell)

$ErrorActionPreference = "Stop"

$ClaudeDir = "$env:USERPROFILE\.claude"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "EazyCheck 설치 시작..."

# 0. Python 확인
$PythonCmd = $null
try {
    $ver = & python --version 2>&1
    if ($ver -match "Python \d") {
        $PythonCmd = "python"
    }
} catch {}

if (-not $PythonCmd) {
    try {
        $ver = & python3 --version 2>&1
        if ($ver -match "Python \d") {
            $PythonCmd = "python3"
        }
    } catch {}
}

if (-not $PythonCmd) {
    Write-Host "Python이 설치되지 않았습니다."
    Write-Host "https://python.org 에서 Python 3.8 이상을 설치해주세요."
    exit 1
}
Write-Host "  Python: $PythonCmd ($(& $PythonCmd --version 2>&1))"

# 1. ~/.claude/ 확인
if (-not (Test-Path $ClaudeDir)) {
    Write-Host "~/.claude/ 폴더가 없습니다. Claude Code를 먼저 설치해주세요."
    exit 1
}

# 2. 폴더 생성
New-Item -ItemType Directory -Force -Path "$ClaudeDir\hooks" | Out-Null
New-Item -ItemType Directory -Force -Path "$ClaudeDir\skills\sim" | Out-Null
New-Item -ItemType Directory -Force -Path "$ClaudeDir\state" | Out-Null

# 3. hooks 복사
Copy-Item "$ScriptDir\hooks\gate-check.py" "$ClaudeDir\hooks\eazycheck-gate.py" -Force
Copy-Item "$ScriptDir\hooks\smart_gate.py" "$ClaudeDir\hooks\eazycheck-smart-gate.py" -Force
Copy-Item "$ScriptDir\hooks\pattern_trigger.py" "$ClaudeDir\hooks\eazycheck-pattern-trigger.py" -Force
Copy-Item "$ScriptDir\hooks\precompact_pattern_save.py" "$ClaudeDir\hooks\eazycheck-precompact.py" -Force
Write-Host "  hooks 설치 완료 (4개)"

# 4. skills 복사
$Skills = @("sim", "systematic-debugging", "writing-plans", "executing-plans", "verification-before-completion", "sequential-thinking", "confidence-check", "brainstorming", "dispatching-parallel-agents", "subagent-driven-development", "using-git-worktrees", "finishing-a-development-branch", "receiving-code-review", "requesting-code-review", "test-driven-development", "prompt-engineering")
$SkillsInstalled = 0
$SkillsSkipped = 0

foreach ($SkillName in $Skills) {
    $SkillSrc = "$ScriptDir\skills\$SkillName\SKILL.md"
    $SkillDstDir = "$ClaudeDir\skills\$SkillName"
    $SkillDst = "$SkillDstDir\SKILL.md"

    if (-not (Test-Path $SkillSrc)) { continue }

    New-Item -ItemType Directory -Force -Path $SkillDstDir | Out-Null

    if (Test-Path $SkillDst) {
        Copy-Item $SkillSrc "$SkillDstDir\eazycheck-preset.md" -Force
        $SkillsSkipped++
    } else {
        Copy-Item $SkillSrc $SkillDst -Force
        $SkillsInstalled++
    }
}
Write-Host "  skills: ${SkillsInstalled}개 설치, ${SkillsSkipped}개 기존 유지"

# 5. patterns.json
if (Test-Path "$ClaudeDir\state\patterns.json") {
    Write-Host "  기존 patterns.json 발견 - 백업 유지 (프리셋은 eazycheck-patterns-preset.json으로 저장)"
    Copy-Item "$ScriptDir\state\patterns.json" "$ClaudeDir\state\eazycheck-patterns-preset.json" -Force
} else {
    Copy-Item "$ScriptDir\state\patterns.json" "$ClaudeDir\state\patterns.json" -Force
    Write-Host "  patterns.json 설치 완료"
}

# 6. CLAUDE.md
if (Test-Path "$ClaudeDir\CLAUDE.md") {
    $content = Get-Content "$ClaudeDir\CLAUDE.md" -Raw -ErrorAction SilentlyContinue
    if ($content -match "EazyCheck") {
        Write-Host "  CLAUDE.md에 EazyCheck 이미 존재 - 건너뜀"
    } else {
        Add-Content "$ClaudeDir\CLAUDE.md" "`n"
        Get-Content "$ScriptDir\CLAUDE.md" | Add-Content "$ClaudeDir\CLAUDE.md"
        Write-Host "  CLAUDE.md에 EazyCheck 추가 완료"
    }
} else {
    Copy-Item "$ScriptDir\CLAUDE.md" "$ClaudeDir\CLAUDE.md" -Force
    Write-Host "  CLAUDE.md 설치 완료"
}

# 7. settings.json hooks 등록
$SettingsFile = "$ClaudeDir\settings.json"
$GatePath = "$ClaudeDir\hooks\eazycheck-gate.py" -replace "\\", "/"
$SmartGatePath = "$ClaudeDir\hooks\eazycheck-smart-gate.py" -replace "\\", "/"
$PatternTriggerPath = "$ClaudeDir\hooks\eazycheck-pattern-trigger.py" -replace "\\", "/"
$PrecompactPath = "$ClaudeDir\hooks\eazycheck-precompact.py" -replace "\\", "/"

if (Test-Path $SettingsFile) {
    $settingsContent = Get-Content $SettingsFile -Raw -ErrorAction SilentlyContinue
    if ($settingsContent -match "eazycheck-gate") {
        Write-Host "  hooks 이미 등록됨 - 건너뜀"
    } else {
        # Python으로 기존 settings.json에 hooks 안전 추가
        try {
            & $PythonCmd -c @"
import json
with open(r'$SettingsFile', 'r', encoding='utf-8') as f:
    settings = json.load(f)
hooks = settings.setdefault('hooks', {})
pre = hooks.setdefault('PreToolUse', [])
pre.append({'matcher': 'Write|Edit|MultiEdit', 'hooks': [{'type': 'command', 'command': '$PythonCmd $GatePath'}]})
user = hooks.setdefault('UserPromptSubmit', [])
user.append({'matcher': '', 'hooks': [{'type': 'command', 'command': '$PythonCmd $SmartGatePath'}, {'type': 'command', 'command': '$PythonCmd $PatternTriggerPath'}]})
compact = hooks.setdefault('PreCompact', [])
compact.append({'matcher': '', 'hooks': [{'type': 'command', 'command': '$PythonCmd $PrecompactPath'}]})
with open(r'$SettingsFile', 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
"@
            Write-Host "  settings.json에 hooks 추가 완료"
        } catch {
            Write-Host ""
            Write-Host "  [수동 설정 필요] settings.json에 hooks를 수동으로 추가해주세요."
            Write-Host "  상세: README.md 참조"
        }
    }
} else {
    # PowerShell 5.1 배열 직렬화 버그 회피: 직접 JSON 문자열 생성
    $jsonContent = @"
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "$PythonCmd $GatePath"
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
            "command": "$PythonCmd $SmartGatePath"
          },
          {
            "type": "command",
            "command": "$PythonCmd $PatternTriggerPath"
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
            "command": "$PythonCmd $PrecompactPath"
          }
        ]
      }
    ]
  }
}
"@
    $jsonContent | Set-Content $SettingsFile -Encoding UTF8
    Write-Host "  settings.json 생성 + hooks 등록 완료"
}

Write-Host ""
Write-Host "EazyCheck 설치 완료!"
Write-Host ""
Write-Host "동작 확인:"
Write-Host "  - API 키를 코드에 쓰면 자동 차단됩니다"
Write-Host "  - 과거 실수와 비슷한 작업 시 자동 경고합니다"
Write-Host "  - 긍정/결정 표현 감지 시 패턴을 자동 축적합니다"
Write-Host "  - 컨텍스트 압축 전 미처리 패턴을 보존합니다"
Write-Host "  - /sim 으로 완성된 코드의 미래 문제를 탐지합니다"

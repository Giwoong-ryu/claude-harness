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
Write-Host "  hooks 설치 완료"

# 4. skills 복사
if (Test-Path "$ClaudeDir\skills\sim\SKILL.md") {
    Write-Host "  기존 sim/SKILL.md 발견 - 건너뜀 (새 버전은 eazycheck-sim-preset.md로 저장)"
    Copy-Item "$ScriptDir\skills\sim\SKILL.md" "$ClaudeDir\skills\sim\eazycheck-sim-preset.md" -Force
} else {
    Copy-Item "$ScriptDir\skills\sim\SKILL.md" "$ClaudeDir\skills\sim\SKILL.md" -Force
    Write-Host "  /sim 스킬 설치 완료"
}

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
user.append({'matcher': '', 'hooks': [{'type': 'command', 'command': '$PythonCmd $SmartGatePath'}]})
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
Write-Host "  - /sim 으로 완성된 코드의 미래 문제를 탐지합니다"

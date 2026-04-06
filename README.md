# ez-harness

AI가 코드를 만들기 전에 조사하고, 설계를 검토하고, 만든 후에 미래 문제를 시뮬레이션합니다.

**Claude Code**와 **Antigravity**에서 동작합니다.

**핵심 흐름: 리서치 -> 플랜 -> 타당성 검토 -> 고도화 -> 코딩 -> 검증**

---

## 왜 필요한가

AI에게 코드를 맡기면 반복되는 실패 패턴이 있습니다:

- 파일을 읽지 않고 기억으로 설명하다가 틀림 (할루시네이션)
- 증상만 고치고 근본 원인은 그대로 둠 (증상 패치)
- 설계 검토 없이 코드부터 작성해서 나중에 구조 문제 발견
- 한 곳의 버그를 고치면 같은 유형이 다른 곳에서 재발
- 근본 원인이 아닌 증상 위치에 fallback만 추가 (새 버그 발생)

이 하네스는 이 패턴들을 구조적으로 차단합니다.

참고: [CodeRabbit 2026 리포트](https://www.coderabbit.ai/blog/ai-code-review-stats)에 따르면 AI 생성 코드는 인간 대비 전체 이슈 1.7배, 보안 취약점 2.74배, 에러 핸들링 미흡 2배입니다.

---

## 구성요소

| 단계 | 이름 | 역할 | 트리거 |
|------|------|------|--------|
| 0 | **역추적** | 버그 근본 원인 확정 후 수정 | 에러/버그 키워드 감지 |
| 1 | **GATE** | 패턴 DB 로드, 관련 경고 출력 | 코드 생성 전 1회 |
| 2 | **위험도 판단** | 8요소 채점 -> LOW/MID/HIGH | 코드 전 |
| 3 | **리서치** | 최신 라이브러리, 베스트 프랙티스 조사 | MID+ 위험도 |
| 4 | **DMAD 토론** | 설계자 vs 사용자 관점 문답 | MID+ 위험도 |
| 5 | **구현 명세** | 파일/함수 범위 + 완료 기준 작성 | DMAD 후 |
| 6 | **sim** | 3개월+10배 실패 시뮬레이션 (P0/P1/P2) | MID+ 위험도, 코드 후 |
| 7 | **smartLoop** | 실패 유형별 최소 지점에서 재시작 | sim/Check 실패 시 |

### 위험도 판단 (8요소 채점)

단순 파일 수가 아니라 8개 요소로 채점합니다:

| 요소 | 조건 | 점수 |
|------|------|------|
| 파일 수 | 3-5: +1, 6-9: +2, 10+: +3 | 0-3 |
| 신규 의존성 | 새 라이브러리/패키지 추가 | +1 |
| DB/스키마 | 마이그레이션, 테이블 변경 | +2 |
| 인증/보안 | auth, 권한, 토큰, 암호화 | +2 |
| API 계약 | 엔드포인트 추가/변경 | +1 |
| 외부 연동 | 3rd party API, webhook | +1 |
| 신규 사용자 기능 | 새 UI, 새 워크플로우 | +1 |
| 기존 코드 삭제/교체 | 파일 삭제, 함수 교체 | +1 |

**0-1 = LOW** (바로 코딩), **2-3 = MID** (리서치 + 토론 + sim), **4+ = HIGH** (풀 파이프라인 2라운드)

### 리서치

DMAD 토론 전에 AI가 최신 라이브러리, 베스트 프랙티스, 유사 구현 사례를 조사합니다. 결과는 `research.md`에 저장되어 구현 시 참조합니다.

### DMAD 토론

코드 작성 전, 두 관점이 문답합니다:

**설계자 (순방향):** 더 단순한 방법? 기존 코드와 충돌? 가장 위험한 가정? 코드 중복? 코드가 흩어지나?

**사용자 (역방향):** 처음 보는 사람이 쓸 수 있나? 자연스럽게 동작하나? 실패 시 복구 가능한가? 에러가 조용히 삼켜지는 곳은?

핵심 규칙:
- 토론 시작 전 변경 대상 파일 전부 Read 필수
- 문제 제기 시 `파일명:라인: 코드내용` 형식으로 직접 인용
- 인용 없는 주장 금지 (오독 할루시네이션 전파 차단)

인용 규칙이 왜 필요한지: [`docs/dmad-false-positive-analysis.md`](claude-code/docs/dmad-false-positive-analysis.md)

### 구현 명세

DMAD 합의 후, 코딩 전에 명세를 작성합니다:
- 파일별 함수/변경 범위 + 리서치 참조
- 완료 기준 (PASS/FAIL 채점 가능한 형태)
- sim이 이 완료 기준으로 채점

### sim (장기 실패 시뮬레이션)

가장 큰 차별점. **아직 발생하지 않은 버그를 배포 전에 잡습니다.**

```
S1. "3개월 후 + 10배 규모" 시뮬레이션 — 코드를 한 줄씩 따라가며 터지는 곳 찾기
    - [P0] 블로커 / [P1] 필수수정 / [P2] 개선 태그
    - 기존 코드 충돌: 새 raise/return이 기존 except/if에 잡히는지 확인
    - 구현 명세의 완료 기준으로 채점
S2. 근본 원인 루프 — "이걸 고치려면 다른 걸 먼저 고쳐야 하나?" → 최하위 레이어까지
S3. 수정 위치 강제 검증: S2 근본 원인 위치 = S3 수정 위치 (불일치 시 수정 금지)
    - fallback 패턴 금지: 증상 우회 차단, 근본 원인만 수정
```

코드를 잘 모르는 상태에서 AI에게 맡길 때 특히 유용합니다. AI가 표면 증상만 고치고 끝내는 패턴을 구조적으로 차단합니다.

`/sim`으로 언제든 수동 실행 가능합니다.

### smartLoop

문제가 해결될 때까지 최대 3회 반복. 전체를 처음부터 재시작하지 않고 실패 유형별 최소 지점에서 재시작합니다.

| 실패 유형 | 재시작 지점 |
|----------|------------|
| lint 오류 | 직접 수정만 |
| 빌드 실패 | 역추적만 재실행 |
| sim FAIL | sim S2부터 |
| 설계 결함 | 전체 재시작 |

3회 후에도 실패 시 사용자에게 보고하고 승인을 기다립니다.

---

## Hooks (선택 — 자동 보호)

`hooks/` 폴더에 Python 스크립트 2개가 자동 보호를 제공합니다:

| Hook | 이벤트 | 기능 |
|------|--------|------|
| `gate-check.py` | PreToolUse (Write/Edit) | API 키 하드코딩 차단 + 반복 실수 경고 |
| `smart_gate.py` | UserPromptSubmit | 관련 패턴 자동 경고 |

**선택사항**입니다. 하네스는 hooks 없이도 동작합니다. hooks는 추가 안전장치.

`install.sh`/`install.ps1`로 설치하면 `~/.claude/settings.json`에 자동 등록됩니다.

---

## 파일 구조

```
ez-harness/
├── claude-code/                         # Claude Code 버전
│   ├── CLAUDE.md                        # 시작점 (~60줄, 매 세션 자동 로드)
│   ├── hooks/
│   │   ├── gate-check.py               # API 키 차단 + 패턴 경고
│   │   └── smart_gate.py               # 관련 패턴 자동 주입
│   ├── state/
│   │   ├── routing.json                 # DMAD 역할 + smartLoop + 트리거
│   │   └── patterns.json               # 패턴 DB (사용할수록 축적)
│   ├── rules/
│   │   └── eazycheck.md                # 위험도 판단 + 분기 규칙 (~70줄, 매 세션)
│   ├── skills/
│   │   └── sim/SKILL.md                 # /sim 실패 시뮬레이션 (/sim 호출 시만)
│   └── docs/
│       ├── eazycheck-detail.md          # GATE+리서치+DMAD+sim 상세 (MID+ 시만)
│       ├── pattern-system.md            # 패턴 축적 3Phase (패턴 작업 시만)
│       └── dmad-false-positive-analysis.md
│
├── antigravity/                         # Antigravity 버전
│   ├── RULES.md                         # 전역 규칙 (역추적 + GATE + DMAD + sim + smartLoop)
│   └── .agents/
│       ├── workflows/sim.md             # /sim 워크플로우
│       └── skills/sim/SKILL.md          # sim 스킬
│
├── install.sh                           # Mac/Linux 설치
├── install.ps1                          # Windows 설치
└── ez-harness.html                      # 소개 페이지
```

---

## 설치

### 자동 설치 (권장)

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

git이 없으면 [ZIP 다운로드](https://github.com/ez-claude/ez-harness/archive/refs/heads/main.zip).

설치 스크립트가 하는 일:
1. hooks, skills, patterns를 `~/.claude/`에 복사
2. CLAUDE.md 규칙을 기존 설정에 병합
3. hooks를 `~/.claude/settings.json`에 등록

### 수동 설치

#### 핵심만 (역추적 + 검증 흐름)

`claude-code/CLAUDE.md`를 `~/.claude/CLAUDE.md`에 병합.

#### 전체

```bash
cp -r claude-code/rules/ ~/.claude/rules/
cp -r claude-code/skills/ ~/.claude/skills/
cp -r claude-code/state/ ~/.claude/state/
cp -r claude-code/hooks/ ~/.claude/hooks/
# CLAUDE.md는 기존 파일에 병합 또는 교체
```

### Antigravity

```bash
cp antigravity/RULES.md {프로젝트루트}/RULES.md
cp -r antigravity/.agents/ {프로젝트루트}/.agents/
```

---

## v5 -> v6.1 변경 내역

| 항목 | v5 | v6.1 |
|------|-----|------|
| 분기 기준 | 파일 수 (1-2/3-5/6+) | 위험도 채점 (8요소, 0-1/2-3/4+) |
| 리서치 | 없음 | MID+ 위험도: DMAD 전 최신 정보 조사 |
| 구현 명세 | 없음 | DMAD 후: 파일/함수 범위 + 완료 기준 |
| DMAD 설계자 | 4개 질문 | 5개 (+코로케이션 Q5) |
| DMAD 사용자 | 3개 질문 | 4개 (+silent failure Q4) |
| 자기검증 | 없음 | 코드 후: 위험도 예측 vs 실제 비교 |
| sim 분류 | 심각도 나열 | P0/P1/P2 우선순위 태그 |
| sim 채점 | 기준 없음 | 구현 명세의 완료 기준으로 채점 |
| Hooks | 없음 | gate-check.py + smart_gate.py (선택) |
| 설치 | 수동 cp | install.sh + install.ps1 |

---

## 한계

- Python/FastAPI 프로젝트에서 운용하며 만든 설정입니다. 다른 스택에서는 조정이 필요할 수 있습니다.
- DMAD와 sim은 AI가 실제 파일을 Read해야 동작합니다. 컨텍스트 창이 부족하면 효과가 줄어듭니다.
- DMAD의 도메인 지식 부재 오탐은 여전히 발생합니다. ([상세](claude-code/docs/dmad-false-positive-analysis.md))

---

## 참고

- [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)
- [Martin Fowler - Exploring Generative AI](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Toss Tech - Harness for Team Productivity](https://toss.tech/article/harness-for-team-productivity)
- [CodeRabbit AI Code Review Stats 2026](https://www.coderabbit.ai/blog/ai-code-review-stats)

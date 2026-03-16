# Claude Verification Harness

> "규율은 코드보다 스캐폴딩에서 드러난다" - OpenAI Harness Engineering

Claude Code가 틀릴 수밖에 없는 상황에서도 틀리지 않게 만드는 검증 시스템.

---

## 이게 뭔가

Claude Code에 얹는 **검증 레이어**다.

프롬프트가 아니다. 규칙 파일과 구조화된 파이프라인으로 Claude의 행동을 제어한다.

```
프롬프트 엔지니어링  ⊂  컨텍스트 엔지니어링  ⊂  하네스 엔지니어링
```

하네스는 가장 바깥 레이어다. Claude가 무엇을 해야 하는지가 아니라, **어떻게 틀리지 않을지**를 시스템으로 정의한다.

---

## 왜 만들었나

Claude Code를 쓰다 보면 반복되는 실패 패턴이 있다:

- 코드를 읽지 않고 기억으로 설명하다가 틀림 (할루시네이션)
- 증상 위치만 고치고 근본 원인은 그대로 (증상 패치)
- 설계 검토 없이 코드 작성 후 뒤늦게 구조 문제 발견
- 수정 후 같은 유형 버그가 다른 파일에서 재발

이 패턴들을 구조적으로 차단하는 게 이 하네스의 목적이다.

---

## 구성요소

| 단계 | 이름 | 역할 | 트리거 |
|------|------|------|--------|
| 0 | **역추적** | 버그 근본 원인 확정 | 에러/오류 키워드 감지 |
| 1 | **GATE** | 버전+패턴 로드, 관련 경고 출력 | 코드 생성 전 1회 |
| 2 | **DMAD 토론** | 설계자 vs 사용자 관점 문답 | 3+ 파일 변경 |
| 3 | **sim** | 3개월+10배 장기 실패 시뮬레이션 | 3+ 파일 변경 후 |
| 4 | **Check** | pre-commit + CI + E2E 도구 검증 | 코드 생성 후 |

### 역추적 (Reverse Trace)

버그 수정 전 3문으로 근본 원인을 확정한다.

```
[역추적]
증상: {에러/문제 1줄}
경로: {어떤 입력 → 어디를 거쳐 → 여기서 터짐}
수정 위치: {근본 원인 위치 확정}
```

트리거 키워드: `에러, 오류, 안되, 안됨, 문제, 실패, 버그, 500, 404, crash, fail`

1-5 파일에 적용. 6+ 파일은 sim S2가 더 깊게 커버.

### DMAD 토론 (Diverse Multi-Agent Debate)

코드 작성 전, 두 관점이 문답한다.

**설계자 (순방향):** 기술적 최선 추구
- 더 단순한 방법이 있나?
- 기존 코드 어디와 부딪히나?
- 가장 위험한 가정 하나는?

**사용자 (역방향):** 실제 사용 경험 관점
- 처음 보는 사람이 쓸 수 있나?
- 실패했을 때 알 수 있나?

**핵심 규칙:**
- 토론 시작 전 변경 대상 파일 전부 Read 필수 (기억으로 코드 언급 금지)
- 문제 제기 시 코드 라인 직접 인용: `파일명:라인: 코드내용`
- 인용 없는 주장 금지 (오독 할루시네이션 방지)

### sim (Failure Simulation)

완성된 코드를 "3개월 후 + 규모 10배" 상황에서 따라가며 터지는 곳을 찾는다.

```
S1. 실패 시뮬레이션 - 코드를 실제로 Read 후 추적
S2. 근본 원인 탐색 - 같은 유형 전체 grep
S3. 수정 + 확인 시뮬레이션 (루프 최대 2회)
    → 수정 후 git commit 필수: "[sim] 파일:라인 수정내용"
```

---

## 하네스 정의 충족 여부

| 하네스 구성요소 (출처) | 이 시스템 | 상태 |
|----------------------|----------|------|
| 환경 설계 (OpenAI) | CLAUDE.md + routing.json + rules/ | OK |
| 피드백 루프 (OpenAI) | patterns.json + sim git commit | OK |
| 안전장치 (tistory) | DMAD 인용규칙 + 파일 Read 강제 | OK |
| 검증 루프 (tistory) | sim S1→S2→S3 | OK |
| LLM 평가 하네스 (tistory) | 예비 실험 결과 | 부분 |
| 저점 올리기 (토스) | 최악의 실수 구조적 차단 | OK |
| 관측 가능성 | 미구현 | 로드맵 |
| 오케스트레이션 | 미구현 | 로드맵 |

---

## 예비 실험 결과

> 소규모 샘플 (12회, 단일 프로젝트). 방향성 확인 용도. 추가 검증 필요.

qt-video-saas 프로젝트, Opus/Sonnet 모델 교차 테스트.

| 비교 | 결과 |
|------|------|
| 순차 DMAD vs 병렬 DMAD | 병렬에서 오탐 감소 관찰 |
| 풀버전 vs 경량 | 풀버전이 유효 문제 발견 약 2.7배 |
| 오탐 원인 | 할루시네이션 전파 (설계자 오판 → 사용자로 전파) |
| 차단 방법 | 파일 Read 강제 + 코드 인용 규칙 |

병렬이 오탐을 줄이는 메커니즘은 실제 코드 확인으로 검증됨 (content_type 케이스).

---

## 파일 구조

```
claude-harness/
├── CLAUDE.md              # 메인 하네스 설정 (여기서 시작)
├── rules/
│   ├── eazycheck-v5.md   # GATE + DMAD + sim + Check 상세 규칙
│   └── pattern-system.md # 패턴 축적 시스템
├── state/
│   └── routing.json      # 라우팅 + DMAD 구조 정의
├── skills/
│   └── sim/
│       └── SKILL.md      # 장기 실패 시뮬레이션 스킬
└── docs/
    └── dmad-false-positive-analysis.md  # 오탐 분석 문서
```

---

## 설치

```bash
# Claude Code 전역 설정 폴더에 복사
cp -r rules/ ~/.claude/rules/
cp -r skills/ ~/.claude/skills/
cp -r state/ ~/.claude/state/

# CLAUDE.md는 기존 파일에 병합 또는 덮어쓰기
```

---

## 다른 하네스와의 차이

| | 이 시스템 | Chachamaru127 |
|--|----------|--------------|
| 목적 | 검증 (틀리지 않게) | 오케스트레이션 (자동화) |
| 근거 | 예비 실험 + 메커니즘 분석 | 선언형 가드레일 |
| 특화 | 오탐 방지, 할루시네이션 차단 | Plan→Work→Review 사이클 |

둘은 경쟁 관계가 아니다. 함께 쓰면 더 완성된 하네스가 된다.

---

## 로드맵

- [ ] 관측 가능성 레이어 (에이전트가 직접 로그 접근)
- [ ] 오케스트레이션 레이어 (Plan→Work→Review→Release)
- [ ] 추가 프로젝트 실험 (현재 단일 프로젝트 한계 극복)

---

## 참고

- [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)
- [Martin Fowler - Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Toss Tech - Harness for Team Productivity](https://toss.tech/article/harness-for-team-productivity)

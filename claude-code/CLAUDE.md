# EazyCheck Verification Harness

> 설치 후 자동 동작. docs/에 상세 규칙, 필요할 때만 Read.

---

## 핵심 규칙

1. **버전 잠금** - state/versions.json 우선
2. **보안** - API 키 환경변수만, 하드코딩 금지
3. **검증 후 기록** - 도구로 확인 가능한 건 도구로 확인 먼저

---

## 검증 흐름

```
[1] 버그 키워드 감지? → 역추적 (증상→경로→수정위치 확정)

[2] GATE: hooks가 설치되어 있으면 자동 경고 (추가 Read 불필요)
         hooks 없으면 state/patterns.json Read → 관련 패턴 경고

[3] 위험도 판단 (8요소 채점, 상세: rules/eazycheck.md)
    0-1 = LOW / 2-3 = MID / 4+ = HIGH

[4] 분기:
    LOW:  코드 → 완료
    MID:  Read docs/eazycheck-detail.md
          → 리서치 → DMAD 1R → 구현명세 → 코드 → 자기검증 → sim 1회
    HIGH: Read docs/eazycheck-detail.md
          → 리서치 → DMAD 2R → 구현명세 → 코드 → 자기검증 → sim 루프 2회

[5] 실패 시 smartLoop (최대 3회, 실패 유형별 최소 지점 재시작)
```

---

## /sim (수동 호출 가능)

완성된 코드에 `/sim` → 3개월+10배 상황에서 터지는 곳 찾기.
S1(시뮬레이션) → S2(근본 원인) → S3(수정+확인). 상세: skills/sim/SKILL.md

---

## 패턴 축적 (자동)

hooks가 자동으로 패턴을 축적합니다:
- gate-check: 코드 수정 시 API 키 차단 + 반복 실수 경고
- smart_gate: 메시지마다 관련 패턴 경고
- pattern_trigger: 긍정/결정 표현 감지 -> 패턴 분석 트리거
- precompact: 컨텍스트 압축 전 미처리 패턴 보존

상세: docs/pattern-system.md

---

## 상세 규칙 (필요 시 Read)

| 파일 | 용도 | 로드 시점 |
|------|------|----------|
| rules/eazycheck.md | 위험도 판단 + 분기 + 역추적 + DMAD 핵심 | 매 세션 (자동) |
| docs/eazycheck-detail.md | GATE, 리서치, DMAD, 구현명세, sim, Check 상세 | MID+ 작업 시 |
| docs/pattern-system.md | 패턴 축적 3Phase 상세 | 패턴 축적 시 |
| skills/sim/SKILL.md | /sim 실패 시뮬레이션 절차 | /sim 호출 시 |
| state/patterns.json | 패턴 DB | GATE에서 Read |

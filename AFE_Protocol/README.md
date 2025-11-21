# AFE Protocol E2E 통합 테스트

AFE Protocol의 4대 Pallet (Brain, Eyes, Shield, Heart) 통합 테스트 스위트입니다.

## 📋 목차

- [개요](#개요)
- [4대 Pallet 소개](#4대-pallet-소개)
- [테스트 시나리오](#테스트-시나리오)
- [실행 방법](#실행-방법)
- [파일 구조](#파일-구조)
- [주요 개념](#주요-개념)

## 🎯 개요

AFE Protocol은 Substrate 기반의 탈중앙화 대출 프로토콜로, 다음 4개의 핵심 Pallet으로 구성됩니다:

- **Brain** (pallet-risk-valuation): 위험 평가 및 P_adj 계산
- **Eyes** (pallet-oracle-governance): 가격 오라클
- **Shield** (pallet-zk-verification): LTV 검증
- **Heart** (pallet-stablecoin-lending): 대출 실행 및 담보 관리

이 저장소는 이 4개 Pallet이 실제 환경에서 어떻게 상호작용하는지 검증하는 E2E 통합 테스트를 제공합니다.

## 🧠 4대 Pallet 소개

### Brain: Risk Valuation (위험 평가)

```rust
// P_adj 계산 - 변동성과 유동성을 고려한 조정 가격
let p_adj = RiskValuation::calculate_adjusted_price(
    asset_id,
    volatility,      // 변동성 (%)
    liquidity_depth, // 유동성 깊이
);
```

**주요 기능:**
- 변동성 기반 가격 조정
- Circuit Breaker 발동
- 리스크 지표 모니터링

### Eyes: Oracle Governance (가격 오라클)

```rust
// 실시간 가격 조회
let btc_price = OracleGovernance::get_price(BTC_ASSET_ID)?;

// 가격 업데이트 (신뢰된 오라클만)
OracleGovernance::update_price(origin, asset_id, new_price)?;
```

**주요 기능:**
- 실시간 가격 피드
- 다중 오라클 합의
- 가격 조작 방지

### Shield: ZK Verification (LTV 검증)

```rust
// LTV (Loan-to-Value) 비율 검증
let is_valid = ZkVerification::verify_ltv_ratio(
    collateral_value,
    loan_amount,
    max_ltv,  // 최대 LTV (예: 70%)
)?;
```

**주요 기능:**
- LTV 한도 검증
- 영지식 증명 기반 프라이버시
- 담보 적정성 확인

### Heart: Stablecoin Lending (대출 실행)

```rust
// Credit Score 기반 동적 담보율 계산
let cr_dynamic = Heart::calculate_cr_dynamic(credit_score);
// CS = 90 → CR = 60% (우수 사용자)
// CS = 50 → CR = 80% (일반 사용자)
// CS = 20 → CR = 95% (고위험 사용자)

// 대출 실행
let loan_id = Heart::borrow(
    origin,
    collateral_asset,
    collateral_amount,
    loan_amount,
    credit_score,
)?;
```

**주요 기능:**
- Credit Score 기반 맞춤형 담보율
- 다단계 청산 메커니즘
- 담보율 실시간 모니터링

## 🧪 테스트 시나리오

### 시나리오 1: 정상 대출 플로우

**목적:** 4대 Pallet의 정상적인 통합 작동 검증

**플로우:**
```
1. Eyes    → BTC 가격 조회 ($50,000)
2. Brain   → P_adj 계산 (변동성/유동성 고려)
3. Shield  → LTV 검증 (≤ 70%)
4. Heart   → CR_dynamic 계산 (CS 기반)
5. Heart   → 대출 실행
6. 100블록 → 담보율 모니터링
```

**검증 사항:**
- ✅ 가격 오라클 정상 작동
- ✅ P_adj가 실제 가격보다 보수적
- ✅ LTV 한도 준수
- ✅ 담보율 안정적 유지

**실행:**
```bash
cargo test --test integration scenario_1_normal_loan_flow -- --nocapture
```

### 시나리오 2: The Great Crash

**목적:** 극단적 시장 붕괴 상황에서의 프로토콜 복원력 검증

**역사적 배경:**
- 2008 금융위기: 주요 자산 -50% 이상 하락
- 2020.03 코로나: BTC -50% (24시간 이내)
- 2022 Terra/Luna: -99% 붕괴

**시나리오 진행:**
```
Phase 1: -20% 하락 ($50k → $40k)
  → 경고 발생

Phase 2: -35% 하락 ($50k → $32.5k)
  → Circuit Breaker 발동
  → Stage 1: DeRisk (담보 추가 요청)

Phase 3: -45% 하락 ($50k → $27.5k)
  → Stage 2: PartialLiquid (담보 30% 청산)

Phase 4: -50% 하락 ($50k → $25k) 🚨
  → Stage 3: EmergencyStop (완전 청산)
  → 보험 풀 활성화
  → 프로토콜 일시 정지

Recovery: +40% 회복 ($25k → $35k)
  → 시스템 재개 검토
```

**3단계 청산 메커니즘:**

| 단계 | 조건 | 조치 |
|------|------|------|
| Stage 1: DeRisk | CR < CR_dynamic + 20% | 담보 추가 요청 (48시간) |
| Stage 2: PartialLiquid | CR < CR_dynamic + 10% | 담보 30% 청산 + 5% 수수료 |
| Stage 3: EmergencyStop | CR < CR_dynamic | 완전 청산 + 프로토콜 정지 |

**검증 사항:**
- ✅ Circuit Breaker 즉각 발동
- ✅ 단계별 청산 정상 작동
- ✅ 보험 풀 손실 방지
- ✅ 프로토콜 재무 건전성 유지

**실행:**
```bash
cargo test --test integration scenario_2_the_great_crash -- --nocapture
```

**추가 크래시 테스트:**
```bash
# Flash Crash (순간 급락/회복)
cargo test --test integration test_flash_crash -- --nocapture

# Slow Bleed (장기 하락장, Crypto Winter)
cargo test --test integration test_slow_bleed_bear_market -- --nocapture

# 대규모 동시 청산 스트레스 테스트
cargo test --test integration test_mass_liquidation_stress -- --nocapture
```

### 시나리오 3: 우수 사용자 혜택

**목적:** Credit Score 기반 차별화된 혜택 검증

**비교 분석:**

| 구분 | 우수 사용자 (CS=90) | 일반 사용자 (CS=50) | 차이 |
|------|---------------------|---------------------|------|
| CR_dynamic | 60% | 80% | -20%p |
| 최대 대출 (1 BTC 담보) | $83,333 | $62,500 | +33% |
| 필요 담보 ($30k 대출) | 0.36 BTC | 0.48 BTC | -25% |
| 가격 하락 여유 | 40% | 20% | +20%p |

**혜택:**
1. **낮은 담보율**: 60% vs 80% (-20%p)
2. **높은 대출 한도**: 33% 더 많이 빌림
3. **담보 효율성**: 25% 담보 절약
4. **안전 마진**: 가격 변동에 더 큰 여유

**실행:**
```bash
cargo test --test integration scenario_3_excellent_user_benefits -- --nocapture
```

## 🚀 실행 방법

### 전체 테스트 실행

```bash
# 모든 통합 테스트 실행
cargo test --test integration

# 상세 로그 포함
cargo test --test integration -- --nocapture

# 특정 시나리오만 실행
cargo test --test integration scenario_1
cargo test --test integration scenario_2
cargo test --test integration scenario_3
```

### 개별 테스트 실행

```bash
# 정상 대출 플로우
cargo test --test integration scenario_1_normal_loan_flow -- --nocapture

# The Great Crash
cargo test --test integration scenario_2_the_great_crash -- --nocapture

# 우수 사용자 혜택
cargo test --test integration scenario_3_excellent_user_benefits -- --nocapture

# Flash Crash
cargo test --test integration test_flash_crash -- --nocapture

# 여러 사용자 동시 대출
cargo test --test integration test_multiple_users_concurrent_loans -- --nocapture

# LTV 한도 초과
cargo test --test integration test_ltv_limit_exceeded -- --nocapture
```

### 벤치마크 모드

```bash
cargo test --test integration --release
```

## 📁 파일 구조

```
AFE_Protocol/
├── Cargo.toml                          # 프로젝트 의존성
├── README.md                           # 이 문서
└── tests/
    └── integration/
        ├── mod.rs                      # 테스트 모듈 정의
        ├── integration_helpers.rs      # 공통 헬퍼 함수
        ├── e2e_scenarios.rs            # 시나리오 1, 3
        └── great_crash_scenario.rs     # 시나리오 2 (The Great Crash)
```

### 파일 설명

#### `integration_helpers.rs`
공통 테스트 유틸리티 및 헬퍼 함수:
- Mock 런타임 설정
- 블록 진행 헬퍼
- 4대 Pallet 호출 래퍼
- 담보율/LTV 계산 함수
- 청산 단계 판정
- Assertion 헬퍼

#### `e2e_scenarios.rs`
정상 플로우 및 우수 사용자 시나리오:
- 시나리오 1: 정상 대출 플로우
- 시나리오 3: 우수 사용자 혜택
- 추가: 여러 사용자 동시 대출
- 추가: LTV 한도 초과 테스트

#### `great_crash_scenario.rs`
극단적 시장 붕괴 시나리오:
- 시나리오 2: The Great Crash (주요)
- 추가: Flash Crash
- 추가: Slow Bleed (Crypto Winter)
- 추가: 대규모 동시 청산 스트레스 테스트

## 📚 주요 개념

### P_adj (Adjusted Price)

변동성과 유동성을 고려한 조정 가격:

```
P_adj = P_market × (1 - volatility_factor) × liquidity_multiplier
```

- 높은 변동성 → P_adj 감소 (보수적)
- 낮은 유동성 → P_adj 감소 (안전)

### CR_dynamic (Dynamic Collateral Ratio)

Credit Score 기반 동적 담보율:

```rust
match credit_score {
    90..=100 => 60%,  // 우수 사용자
    70..=89  => 70%,
    50..=69  => 80%,  // 일반 사용자
    30..=49  => 90%,
    0..=29   => 95%,  // 고위험 사용자
}
```

### LTV (Loan-to-Value)

대출 비율:

```
LTV = Loan Amount / Collateral Value × 100%
```

예: 담보 $50,000, 대출 $30,000 → LTV = 60%

### 담보율 (Collateral Ratio)

```
CR = Collateral Value / Loan Amount × 100%
```

예: 담보 $50,000, 대출 $30,000 → CR = 166%

### 건강도 (Health Factor)

```
Health = (Collateral Value / Required Collateral) × 100%
```

- Health > 100%: 안전
- Health = 100%: 청산 임계점
- Health < 100%: 청산 대상

### Circuit Breaker

급격한 가격 변동 감지 시 자동 발동:
- 신규 대출 중단
- 오라클 업데이트 빈도 증가
- 리스크 팀 알림
- 시스템 보호 모드 진입

## 🔧 개발 가이드

### 새 테스트 추가

1. `e2e_scenarios.rs` 또는 `great_crash_scenario.rs`에 함수 추가
2. `#[test]` 속성 부여
3. `new_test_ext().execute_with(|| { ... })` 사용
4. `test_log!` 매크로로 로그 출력

예시:
```rust
#[test]
fn test_my_scenario() {
    new_test_ext().execute_with(|| {
        test_log!("나의 테스트 시나리오");

        // 테스트 로직...

        test_log!("✅ 테스트 완료!");
    });
}
```

### 헬퍼 함수 추가

`integration_helpers.rs`에 공통 함수 추가:

```rust
pub fn my_helper_function(param: Type) -> Result<ReturnType, &'static str> {
    // 구현...
}
```

## 📊 테스트 커버리지

현재 커버리지:
- ✅ 정상 대출 플로우
- ✅ 가격 급락 시나리오
- ✅ Circuit Breaker 발동
- ✅ 3단계 청산 메커니즘
- ✅ Credit Score 차별화
- ✅ 여러 사용자 동시 대출
- ✅ LTV 한도 검증
- ✅ Flash Crash
- ✅ Slow Bleed
- ✅ 대규모 청산

## 🎓 배운 교훈

### 1. 충분한 담보율의 중요성
- 최소 CR_dynamic + 20% 이상 유지 권장
- 가격 변동에 대비한 안전 마진 필수

### 2. 실시간 모니터링
- 블록마다 담보율 확인
- Circuit Breaker로 급격한 변동 대응

### 3. 다단계 방어선
- Stage 1: DeRisk (경고)
- Stage 2: PartialLiquid (부분 대응)
- Stage 3: EmergencyStop (완전 대응)

### 4. 보험 풀의 중요성
- 극단적 상황 대비
- 프로토콜 재무 건전성 유지

### 5. Credit Score 시스템
- 우수 사용자에게 인센티브
- 리스크 기반 차별화

## 🤝 기여하기

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-test`)
3. Add your test
4. Commit your changes (`git commit -am 'Add new test scenario'`)
5. Push to the branch (`git push origin feature/my-test`)
6. Create a Pull Request

## 📝 라이선스

Copyright © 2025 HTS Global Intelligence Team

## 📞 연락처

- 프로젝트: HTS Global Intelligence Base
- 이메일: [contact@hts-global.io]
- 문서: [docs.afe-protocol.io]

---

**Made with ❤️ by HTS Global Intelligence Team**

**"Building the future of decentralized lending"**

# pallet-stablecoin-lending

**AFE Protocol의 핵심 (The Heart)** - 기여도 기반 동적 담보율 스테이블코인 대출 시스템

## 개요

AFE Protocol의 Stablecoin Lending Pallet은 혁신적인 **기여도 점수 (CS)** 시스템과 **3단계 청산 방지 메커니즘**을 통해 안정적이고 공정한 스테이블코인 대출 서비스를 제공합니다.

### 핵심 특징

- 📊 **기여도 점수 (CS)**: 사용자의 플랫폼 기여도를 정량화하여 공정한 대출 조건 제공
- 🎯 **동적 담보율 (CR_dynamic)**: CS에 따라 50%-150% 범위로 자동 조정
- 🛡️ **3단계 청산 방지**: De-Risk, Partial Liquidation, Emergency Stop으로 안정성 보장
- 🔗 **통합 아키텍처**: Brain (가격 오라클), Shield (신뢰 검증) 연동 준비
- ⚡ **실시간 모니터링**: 블록마다 모든 금고의 담보율 자동 모니터링

## 핵심 공식

### 1. 기여도 점수 (Contribution Score)

```
CS = 0.30×LP + 0.25×TV + 0.20×GP + 0.15×HD + 0.10×TS
```

- **LP (Liquidity Provision)**: 유동성 제공 점수 (0-100)
- **TV (Total Value Locked)**: 총 예치 가치 점수 (0-100)
- **GP (Governance Participation)**: 거버넌스 참여 점수 (0-100)
- **HD (Historical Debt)**: 과거 부채 이력 점수 (0-100)
- **TS (Tenure Score)**: 재직 기간 점수 (0-100)

### 2. 동적 담보율 (Dynamic Collateral Ratio)

```
CR_dynamic = 150% - CS
```

- **범위**: 50% ~ 150%
- CS가 높을수록 낮은 담보율로 대출 가능
- 예시:
  - CS = 0 → CR = 150% (최대)
  - CS = 50 → CR = 100% (중간)
  - CS = 100 → CR = 50% (최소)

### 3. 최대 대출 가능 금액

```
V_loan_max = V_collateral / CR_dynamic
```

- **V_collateral**: 담보 가치 (담보 수량 × 자산 가격)
- **CR_dynamic**: 동적 담보율

## 3단계 청산 방지 시스템

### Stage 1: De-Risk (145% ~ 150%)

- **목적**: 차익거래 유도
- **행동**: 사용자에게 경고 및 담보 추가 권장
- **상태**: `DeRisk`

### Stage 2: Partial Liquidation (140% ~ 145%)

- **목적**: 부분 청산으로 건강성 회복
- **행동**: 청산자가 부채 일부를 상환하고 담보 일부 획득 (5% 인센티브)
- **상태**: `PartialLiquid`

### Stage 3: Emergency Stop (< 140%)

- **목적**: 시스템 보호를 위한 긴급 청산
- **행동**: 전체 담보 청산 및 금고 종료
- **상태**: `EmergencyStop`

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                   AFE Protocol                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐     │
│  │  Shield  │────▶ │  Heart   │ ◀────│  Brain   │     │
│  │ (Trust)  │      │(Lending) │      │ (Risk)   │     │
│  └──────────┘      └──────────┘      └──────────┘     │
│       │                  │                  │          │
│       │                  │                  │          │
│   LTV/KYC          CS Calculation      Price Oracle    │
│   Verification     Loan Execution      Risk Adjustment │
│                    Liquidation                         │
└─────────────────────────────────────────────────────────┘
```

### 연동 인터페이스

#### Shield (Trust Verifier)

```rust
// TODO: Shield 연동 시 활성화
// ensure!(
//     T::TrustVerifier::has_valid_ltv_proof(&borrower),
//     Error::<T>::LtvProofNotFound
// );
// ensure!(
//     T::TrustVerifier::verify_kyc(&borrower),
//     Error::<T>::KycVerificationFailed
// );
```

#### Brain (Risk Manager)

```rust
// TODO: Brain 연동 시 활성화
// let adjusted_price = T::RiskManager::get_adjusted_price(asset_id)
//     .ok_or(Error::<T>::PriceOracleError)?;
```

## 주요 기능

### 1. 대출 실행 (execute_loan)

사용자가 담보를 예치하고 스테이블코인을 대출받습니다.

```rust
pub fn execute_loan(
    origin: OriginFor<T>,
    asset_id: AssetId,
    collateral_amount: Balance,
    loan_amount: Balance,
) -> DispatchResult
```

**프로세스**:
1. LTV/KYC 검증 (Shield)
2. 조정된 가격 조회 (Brain)
3. CS 계산 및 CR_dynamic 결정
4. 대출 가능 금액 확인
5. 담보 예치 (Reserve)
6. LoanVault 생성
7. 스테이블코인 발행

### 2. 대출 상환 (repay_loan)

사용자가 스테이블코인을 반환하고 부채를 감소시킵니다.

```rust
pub fn repay_loan(
    origin: OriginFor<T>,
    loan_id: LoanId,
    repay_amount: Balance,
) -> DispatchResult
```

**프로세스**:
1. 이자 업데이트
2. 스테이블코인 소각
3. 부채 감소 (이자 우선 상환)
4. 전액 상환 시 담보 반환 및 금고 삭제

### 3. 담보 추가 (add_collateral)

사용자가 추가 담보를 예치하여 담보율을 개선합니다.

```rust
pub fn add_collateral(
    origin: OriginFor<T>,
    loan_id: LoanId,
    additional_collateral: Balance,
) -> DispatchResult
```

### 4. 부분 청산 (partial_liquidate)

PartialLiquid 상태의 금고를 청산자가 부분 청산합니다.

```rust
pub fn partial_liquidate(
    origin: OriginFor<T>,
    loan_id: LoanId,
    repay_amount: Balance,
) -> DispatchResult
```

**청산 인센티브**: 5% (설정 가능)

**계산 공식**:
```
collateral_to_liquidate = (repay_amount / price) × (1 + 0.05)
```

### 5. 긴급 청산 (emergency_liquidate)

EmergencyStop 상태의 금고를 청산자가 전체 청산합니다.

```rust
pub fn emergency_liquidate(
    origin: OriginFor<T>,
    loan_id: LoanId,
) -> DispatchResult
```

### 6. 기여도 점수 업데이트 (update_contribution_score)

관리자가 사용자의 기여도 점수를 업데이트합니다.

```rust
pub fn update_contribution_score(
    origin: OriginFor<T>,
    account: AccountId,
    lp: u32,
    tv: u32,
    gp: u32,
    hd: u32,
    ts: u32,
) -> DispatchResult
```

## 스토리지

### Vaults

대출 금고 정보를 저장합니다.

```rust
pub type Vaults<T: Config> = StorageMap<_, Blake2_128Concat, LoanId, LoanVault<T>>;
```

**LoanVault 구조**:
- `borrower`: 차입자 계정
- `collateral_asset_id`: 담보 자산 ID
- `collateral_amount`: 담보 금액
- `debt_amount`: 부채 금액
- `collateral_ratio`: 담보율 (basis points)
- `interest_rate`: 이자율 (basis points)
- `last_update_block`: 마지막 업데이트 블록
- `status`: 금고 상태 (Active, DeRisk, PartialLiquid, EmergencyStop)
- `accrued_interest`: 누적 이자

### ContributionScores

사용자별 기여도 점수를 저장합니다.

```rust
pub type ContributionScores<T: Config> = StorageMap<_, Blake2_128Concat, AccountId, ContributionScoreDetails>;
```

### UserLoans

사용자별 대출 ID 목록을 저장합니다.

```rust
pub type UserLoans<T: Config> = StorageMap<_, Blake2_128Concat, AccountId, BoundedVec<LoanId, MaxLoans>>;
```

### TotalSupply

총 발행된 스테이블코인 양을 저장합니다.

```rust
pub type TotalSupply<T: Config> = StorageValue<_, Balance>;
```

## 이벤트

- **LoanIssued**: 대출 발행됨
- **LoanRepaid**: 대출 상환됨
- **CollateralAdded**: 담보 추가됨
- **VaultStatusChanged**: 금고 상태 변경됨
- **PartialLiquidation**: 부분 청산 실행됨
- **EmergencyLiquidation**: 긴급 청산 실행됨
- **ContributionScoreUpdated**: 기여도 점수 업데이트됨
- **InterestAccrued**: 이자 발생됨
- **AssetPriceUpdated**: 자산 가격 업데이트됨 (모의용)

## 에러

- **InsufficientCollateral**: 담보 부족
- **VaultNotFound**: 금고를 찾을 수 없음
- **InvalidLoanAmount**: 잘못된 대출 금액
- **ArithmeticError**: 산술 연산 오류
- **SystemRiskTooHigh**: 시스템 리스크가 너무 높음
- **Unauthorized**: 권한 없음
- **VaultAlreadyLiquidated**: 금고가 이미 청산됨
- **LiquidationConditionNotMet**: 청산 조건 미충족
- **MaxLoansExceeded**: 최대 대출 수 초과
- **InvalidCollateralRatio**: 잘못된 담보율
- **VaultNotActive**: 대출이 활성 상태가 아님
- **RepaymentTooLarge**: 상환 금액이 너무 큼
- **InsufficientBalance**: 잔액 부족

## 설정 파라미터

```rust
parameter_types! {
    pub const MaxLoans: u32 = 10_000;                      // 최대 대출 수
    pub const MinCollateralRatio: u32 = 5_000;             // 50%
    pub const BaseCollateralRatio: u32 = 15_000;           // 150%
    pub const DeRiskThreshold: u32 = 14_500;               // 145%
    pub const PartialLiquidationThreshold: u32 = 14_000;   // 140%
    pub const EmergencyThreshold: u32 = 14_000;            // 140%
    pub const BaseInterestRate: u32 = 500;                 // 연 5%
    pub const LiquidationIncentive: u32 = 500;             // 5%
}
```

## 사용 예시

### 대출 실행

```rust
// 자산 가격 설정 (모의용, Brain 연동 전)
StablecoinLending::update_asset_price(
    RuntimeOrigin::root(),
    ETH, // asset_id = 1
    2000 // 1 ETH = 2000 USD
)?;

// 기여도 점수 설정
StablecoinLending::update_contribution_score(
    RuntimeOrigin::root(),
    ALICE,
    80, // LP
    70, // TV
    60, // GP
    50, // HD
    40  // TS
)?;

// 대출 실행
// 담보: 10 ETH × 2000 = 20,000 USD
// CS ≈ 65 → CR ≈ 85%
// 최대 대출: 20,000 / 0.85 ≈ 23,529 USD
StablecoinLending::execute_loan(
    RuntimeOrigin::signed(ALICE),
    ETH,
    10,     // 10 ETH 담보
    20000   // 20,000 USD 대출
)?;
```

### 담보 추가

```rust
StablecoinLending::add_collateral(
    RuntimeOrigin::signed(ALICE),
    loan_id,
    5 // 5 ETH 추가
)?;
```

### 대출 상환

```rust
StablecoinLending::repay_loan(
    RuntimeOrigin::signed(ALICE),
    loan_id,
    10000 // 10,000 USD 상환
)?;
```

## 테스트

### 테스트 실행

```bash
cargo test --package pallet-stablecoin-lending
```

### 테스트 커버리지

1. ✅ **CS 계산**: 기여도 점수 계산 검증
2. ✅ **CR_dynamic 계산**: 동적 담보율 계산 검증
3. ✅ **대출 실행**: 정상적인 대출 프로세스 검증
4. ✅ **담보 추가**: 담보 추가 및 담보율 개선 검증
5. ✅ **대출 상환**: 부분/전액 상환 검증
6. ✅ **Stage 1 De-Risk**: 차익거래 유도 단계 검증
7. ✅ **Stage 2 Partial Liquidation**: 부분 청산 검증
8. ✅ **Stage 3 Emergency Stop**: 긴급 청산 검증
9. ✅ **담보 부족**: 대출 실패 검증
10. ✅ **권한 검증**: 무단 접근 방지 검증
11. ✅ **이자 발생**: 시간 경과에 따른 이자 계산 검증
12. ✅ **높은 CS**: 높은 기여도 점수로 낮은 담보율 적용 검증
13. ✅ **청산 조건**: 청산 조건 미충족 시 실패 검증
14. ✅ **점수 업데이트**: 기여도 점수 업데이트 검증
15. ✅ **잘못된 점수**: 유효하지 않은 점수 입력 검증

## Runtime 통합

### 1. Cargo.toml 의존성 추가

```toml
[dependencies]
pallet-stablecoin-lending = { path = "../pallets/stablecoin-lending", default-features = false }
pallet-balances = { version = "4.0.0-dev", default-features = false }
```

### 2. Runtime 구성

```rust
construct_runtime!(
    pub enum Runtime {
        System: frame_system,
        Balances: pallet_balances,
        StablecoinLending: pallet_stablecoin_lending,
    }
);

impl pallet_stablecoin_lending::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type Currency = Balances;
    type MaxLoans = ConstU32<10_000>;
    type MinCollateralRatio = ConstU32<5_000>;
    type BaseCollateralRatio = ConstU32<15_000>;
    type DeRiskThreshold = ConstU32<14_500>;
    type PartialLiquidationThreshold = ConstU32<14_000>;
    type EmergencyThreshold = ConstU32<14_000>;
    type BaseInterestRate = ConstU32<500>;
    type LiquidationIncentive = ConstU32<500>;
}
```

## 향후 개선 사항

### Brain 연동
- [ ] 실시간 가격 오라클 통합
- [ ] 리스크 조정 가격 (P_adj) 적용
- [ ] 시장 변동성 기반 동적 파라미터 조정

### Shield 연동
- [ ] LTV (Loan-to-Value) 증명 검증
- [ ] KYC (Know Your Customer) 검증
- [ ] 영지식 증명 기반 프라이버시 보호

### 스테이블코인 발행
- [ ] 실제 스테이블코인 토큰 발행 로직
- [ ] 소각 메커니즘 구현
- [ ] 총 공급량 관리

### 거버넌스
- [ ] 파라미터 조정 제안 및 투표
- [ ] 긴급 중단 메커니즘
- [ ] 다중 서명 관리자 지원

### 최적화
- [ ] 배치 청산 지원
- [ ] 가스 최적화
- [ ] 벤치마크 및 가중치 조정

## 라이선스

Unlicense

## 기여

AFE Protocol Team에 의해 개발되었습니다.

## 문의

- GitHub: https://github.com/Geserkhan/HTS_Global_Intelligence_Base
- 이슈: https://github.com/Geserkhan/HTS_Global_Intelligence_Base/issues

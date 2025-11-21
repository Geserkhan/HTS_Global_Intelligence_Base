# Pallet Stablecoin Lending (Heart)

## 개요

AFE Protocol의 핵심 팔렛인 Heart는 기여도 기반 동적 담보율을 사용하는 Stablecoin Lending 시스템입니다.

## 주요 기능

### 1. 기여도 점수 (Contribution Score, CS)

사용자의 생태계 기여도를 0-100 점수로 평가:

```
CS = 0.30 × LP + 0.25 × TV + 0.20 × GP + 0.15 × HD + 0.10 × TS
```

- **LP (Liquidity Provision)**: 유동성 제공 점수
- **TV (Total Value Locked)**: 총 예치 가치
- **GP (Governance Participation)**: 거버넌스 참여도
- **HD (Historical Debt)**: 과거 대출 이력
- **TS (Tenure Score)**: 재임 기간 점수

### 2. 동적 담보율 (Dynamic Collateral Ratio)

```
CR_dynamic = 150% - CS (범위: 50%-150%)
```

- 기본 담보율: 150%
- 최소 담보율: 50%
- CS가 높을수록 낮은 담보율로 대출 가능

### 3. 최대 대출 금액 계산

```
V_loan_max = V_collateral × 100 / CR_dynamic
```

### 4. 3단계 청산 방지 시스템

| 단계 | 담보율 범위 | 상태 | 조치 |
|------|------------|------|------|
| 정상 | ≥ 150% | Active | 정상 운영 |
| 1단계 | 145%-150% | DeRisk | 차익거래 유도 |
| 2단계 | 140%-145% | PartialLiquid | 부분 청산 |
| 3단계 | < 140% | EmergencyStop | 강제 청산 |

## 주요 Extrinsics

### execute_loan

담보를 제공하고 Stablecoin을 대출받습니다.

```rust
pub fn execute_loan(
    origin: OriginFor<T>,
    asset_id: u32,
    collateral_amount: u128,
    loan_amount: u128,
) -> DispatchResult
```

### repay_loan

대출을 상환합니다.

```rust
pub fn repay_loan(
    origin: OriginFor<T>,
    loan_id: u64,
    amount: u128,
) -> DispatchResult
```

### add_collateral

추가 담보를 예치하여 담보율을 개선합니다.

```rust
pub fn add_collateral(
    origin: OriginFor<T>,
    loan_id: u64,
    amount: u128,
) -> DispatchResult
```

### update_contribution_score

사용자의 기여도 점수를 업데이트합니다 (관리자 전용).

```rust
pub fn update_contribution_score(
    origin: OriginFor<T>,
    account: T::AccountId,
    score: u32,
) -> DispatchResult
```

## 통합

### Brain (Oracle Governance) 연동

가격 피드를 Brain 팔렛에서 가져옵니다:

```rust
// 향후 구현 예정
// let adjusted_price = T::RiskManager::get_adjusted_price(asset_id)?;
```

### Shield (ZK Verification) 연동

LTV 증명을 검증합니다:

```rust
// 향후 구현 예정
// ensure!(T::TrustVerifier::has_valid_ltv_proof(&borrower), Error::<T>::LtvProofNotFound);
```

## 라이센스

Apache-2.0

## 작성자

AFE Protocol Team

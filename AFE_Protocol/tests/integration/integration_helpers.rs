//! AFE Protocol 통합 테스트 헬퍼 함수들
//!
//! 4대 Pallet (Brain, Eyes, Shield, Heart)의 통합 테스트를 위한 공통 유틸리티
//! - Brain: pallet_risk_valuation (위험 평가 및 P_adj 계산)
//! - Eyes: pallet_oracle_governance (가격 오라클)
//! - Shield: pallet_zk_verification (LTV 검증)
//! - Heart: pallet_stablecoin_lending (대출 실행 및 담보 관리)

use frame_support::{
    assert_ok, assert_noop,
    traits::{OnFinalize, OnInitialize},
};
use sp_runtime::{
    traits::{BlakeTwo256, IdentityLookup},
    BuildStorage, FixedPointNumber, FixedU128,
};
use sp_core::H256;

/// 테스트 런타임 타입 정의
pub type AccountId = u64;
pub type Balance = u128;
pub type BlockNumber = u64;

/// 고정 소수점 타입 (18 decimals)
pub type Price = FixedU128;

/// 테스트용 상수
pub mod constants {
    use super::*;

    /// 기본 사용자 계정
    pub const ALICE: AccountId = 1;
    pub const BOB: AccountId = 2;
    pub const CHARLIE: AccountId = 3;

    /// 초기 잔액 (1,000,000 USDT)
    pub const INITIAL_BALANCE: Balance = 1_000_000_000_000_000_000_000_000; // 1M with 18 decimals

    /// 자산 ID
    pub const BTC_ASSET_ID: u32 = 1;
    pub const USDT_ASSET_ID: u32 = 2;

    /// 기본 가격 (BTC = $50,000)
    pub const DEFAULT_BTC_PRICE: u128 = 50_000_000_000_000_000_000_000; // $50k with 18 decimals

    /// 담보 금액 (1 BTC)
    pub const DEFAULT_COLLATERAL: Balance = 1_000_000_000_000_000_000; // 1 BTC with 18 decimals

    /// 기본 Credit Score
    pub const DEFAULT_CREDIT_SCORE: u8 = 50;
    pub const HIGH_CREDIT_SCORE: u8 = 90;
    pub const LOW_CREDIT_SCORE: u8 = 20;
}

/// Mock 런타임 설정
pub fn new_test_ext() -> sp_io::TestExternalities {
    let mut storage = frame_system::GenesisConfig::default()
        .build_storage::<TestRuntime>()
        .unwrap();

    // Oracle 초기 가격 설정
    pallet_oracle_governance::GenesisConfig::<TestRuntime> {
        initial_prices: vec![
            (constants::BTC_ASSET_ID, Price::from_inner(constants::DEFAULT_BTC_PRICE)),
        ],
        trusted_oracles: vec![constants::ALICE],
    }
    .assimilate_storage(&mut storage)
    .unwrap();

    // 사용자 초기 잔액 설정
    pallet_balances::GenesisConfig::<TestRuntime> {
        balances: vec![
            (constants::ALICE, constants::INITIAL_BALANCE),
            (constants::BOB, constants::INITIAL_BALANCE),
            (constants::CHARLIE, constants::INITIAL_BALANCE),
        ],
    }
    .assimilate_storage(&mut storage)
    .unwrap();

    storage.into()
}

/// 블록 진행 헬퍼
pub fn run_to_block(n: BlockNumber) {
    while System::block_number() < n {
        let current = System::block_number();

        // 모든 Pallet의 on_finalize 호출
        StablecoinLending::on_finalize(current);
        RiskValuation::on_finalize(current);
        OracleGovernance::on_finalize(current);
        ZkVerification::on_finalize(current);
        System::on_finalize(current);

        // 블록 번호 증가
        System::set_block_number(current + 1);

        // 모든 Pallet의 on_initialize 호출
        System::on_initialize(current + 1);
        OracleGovernance::on_initialize(current + 1);
        RiskValuation::on_initialize(current + 1);
        ZkVerification::on_initialize(current + 1);
        StablecoinLending::on_initialize(current + 1);
    }
}

/// Eyes: 가격 업데이트 헬퍼
pub fn update_btc_price(new_price: u128) -> Result<(), &'static str> {
    let price = Price::from_inner(new_price);
    OracleGovernance::update_price(
        Origin::signed(constants::ALICE),
        constants::BTC_ASSET_ID,
        price,
    )
}

/// Brain: P_adj 계산 헬퍼
pub fn calculate_p_adj(
    asset_id: u32,
    volatility: u32,
    liquidity_depth: Balance,
) -> Result<Price, &'static str> {
    RiskValuation::calculate_adjusted_price(
        asset_id,
        volatility,
        liquidity_depth,
    )
}

/// Shield: LTV 검증 헬퍼
pub fn verify_ltv(
    collateral_value: Balance,
    loan_amount: Balance,
    max_ltv: u32,
) -> Result<bool, &'static str> {
    ZkVerification::verify_ltv_ratio(
        collateral_value,
        loan_amount,
        max_ltv,
    )
}

/// Heart: CR_dynamic 계산 헬퍼 (Credit Score 기반)
pub fn calculate_cr_dynamic(credit_score: u8) -> u32 {
    // CS = 90 → CR_dynamic = 60%
    // CS = 50 → CR_dynamic = 80%
    // CS = 20 → CR_dynamic = 95%

    if credit_score >= 90 {
        60 // 우수 사용자: 낮은 담보율
    } else if credit_score >= 70 {
        70
    } else if credit_score >= 50 {
        80 // 일반 사용자
    } else if credit_score >= 30 {
        90
    } else {
        95 // 고위험 사용자: 높은 담보율
    }
}

/// Heart: 대출 실행 헬퍼
pub fn execute_loan(
    borrower: AccountId,
    collateral_asset: u32,
    collateral_amount: Balance,
    loan_amount: Balance,
    credit_score: u8,
) -> Result<u64, &'static str> {
    StablecoinLending::borrow(
        Origin::signed(borrower),
        collateral_asset,
        collateral_amount,
        loan_amount,
        credit_score,
    )
}

/// 담보율 계산 헬퍼
pub fn calculate_collateral_ratio(
    collateral_value: Balance,
    loan_amount: Balance,
) -> u32 {
    if loan_amount == 0 {
        return u32::MAX;
    }

    let ratio = (collateral_value as u128 * 100) / (loan_amount as u128);
    ratio as u32
}

/// Circuit Breaker 상태 확인 헬퍼
pub fn is_circuit_breaker_active() -> bool {
    RiskValuation::circuit_breaker_status()
}

/// 청산 단계 확인 헬퍼
#[derive(Debug, PartialEq, Eq)]
pub enum LiquidationStage {
    /// 정상: 담보율이 충분함
    Normal,
    /// Stage 1: DeRisk - 담보율 경고 (CR < CR_dynamic + 20%)
    DeRisk,
    /// Stage 2: PartialLiquid - 부분 청산 (CR < CR_dynamic + 10%)
    PartialLiquid,
    /// Stage 3: EmergencyStop - 긴급 중단 (CR < CR_dynamic)
    EmergencyStop,
}

pub fn get_liquidation_stage(
    collateral_ratio: u32,
    cr_dynamic: u32,
) -> LiquidationStage {
    if collateral_ratio >= cr_dynamic + 20 {
        LiquidationStage::Normal
    } else if collateral_ratio >= cr_dynamic + 10 {
        LiquidationStage::DeRisk
    } else if collateral_ratio >= cr_dynamic {
        LiquidationStage::PartialLiquid
    } else {
        LiquidationStage::EmergencyStop
    }
}

/// 가격 변동률 계산 헬퍼 (백분율)
pub fn calculate_price_change_percent(
    old_price: u128,
    new_price: u128,
) -> i32 {
    if old_price == 0 {
        return 0;
    }

    let change = (new_price as i128 - old_price as i128) * 100 / old_price as i128;
    change as i32
}

/// 청산 가치 계산 헬퍼
pub fn calculate_liquidation_value(
    collateral_amount: Balance,
    current_price: Price,
    liquidation_penalty: u32, // 백분율 (예: 5 = 5%)
) -> Balance {
    let value = collateral_amount * current_price.into_inner() / Price::DIV;
    let penalty = value * liquidation_penalty as u128 / 100;
    value - penalty
}

/// 이자 계산 헬퍼 (단순 이자)
pub fn calculate_interest(
    principal: Balance,
    rate_per_block: u32, // 1e6 기준 (예: 1000 = 0.1%)
    blocks: BlockNumber,
) -> Balance {
    let interest = principal * rate_per_block as u128 * blocks as u128 / 1_000_000;
    interest
}

/// 건강도 점수 계산 헬퍼
pub fn calculate_health_factor(
    collateral_value: Balance,
    loan_amount: Balance,
    cr_required: u32,
) -> u32 {
    if loan_amount == 0 {
        return u32::MAX;
    }

    let required_collateral = loan_amount * cr_required as u128 / 100;
    let health = collateral_value * 100 / required_collateral;
    health as u32
}

/// 시뮬레이션: 가격 급락 시나리오
pub fn simulate_price_crash(
    initial_price: u128,
    crash_percent: u32, // 하락 퍼센트 (예: 50 = 50% 하락)
) -> Vec<u128> {
    let mut prices = vec![initial_price];
    let steps = 10; // 10단계로 나누어 하락

    for i in 1..=steps {
        let drop = initial_price * crash_percent as u128 * i / (100 * steps);
        prices.push(initial_price - drop);
    }

    prices
}

/// 로그 출력 헬퍼 (테스트용)
#[macro_export]
macro_rules! test_log {
    ($($arg:tt)*) => {
        #[cfg(test)]
        println!("[TEST LOG] {}", format!($($arg)*));
    };
}

/// Assertion 헬퍼: 가격 범위 확인
pub fn assert_price_in_range(
    actual: Price,
    expected: Price,
    tolerance_percent: u32,
) {
    let diff = if actual > expected {
        actual.into_inner() - expected.into_inner()
    } else {
        expected.into_inner() - actual.into_inner()
    };

    let max_diff = expected.into_inner() * tolerance_percent as u128 / 100;
    assert!(
        diff <= max_diff,
        "Price out of range: actual={:?}, expected={:?}, tolerance={}%",
        actual, expected, tolerance_percent
    );
}

/// Assertion 헬퍼: 담보율 확인
pub fn assert_collateral_ratio_safe(
    collateral_ratio: u32,
    cr_dynamic: u32,
    margin: u32,
) {
    assert!(
        collateral_ratio >= cr_dynamic + margin,
        "Unsafe collateral ratio: {}% < required {}% + {}% margin",
        collateral_ratio, cr_dynamic, margin
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_cr_dynamic() {
        // 우수 사용자 (CS = 90)
        assert_eq!(calculate_cr_dynamic(90), 60);

        // 일반 사용자 (CS = 50)
        assert_eq!(calculate_cr_dynamic(50), 80);

        // 고위험 사용자 (CS = 20)
        assert_eq!(calculate_cr_dynamic(20), 95);
    }

    #[test]
    fn test_liquidation_stage() {
        let cr_dynamic = 80;

        // 정상 (CR = 105%)
        assert_eq!(
            get_liquidation_stage(105, cr_dynamic),
            LiquidationStage::Normal
        );

        // Stage 1: DeRisk (CR = 95%)
        assert_eq!(
            get_liquidation_stage(95, cr_dynamic),
            LiquidationStage::DeRisk
        );

        // Stage 2: PartialLiquid (CR = 85%)
        assert_eq!(
            get_liquidation_stage(85, cr_dynamic),
            LiquidationStage::PartialLiquid
        );

        // Stage 3: EmergencyStop (CR = 75%)
        assert_eq!(
            get_liquidation_stage(75, cr_dynamic),
            LiquidationStage::EmergencyStop
        );
    }

    #[test]
    fn test_price_change_percent() {
        // 50% 하락
        assert_eq!(
            calculate_price_change_percent(50_000, 25_000),
            -50
        );

        // 100% 상승
        assert_eq!(
            calculate_price_change_percent(50_000, 100_000),
            100
        );
    }

    #[test]
    fn test_simulate_price_crash() {
        let prices = simulate_price_crash(50_000, 50);

        // 11개 가격 포인트 (초기 + 10단계)
        assert_eq!(prices.len(), 11);

        // 초기 가격
        assert_eq!(prices[0], 50_000);

        // 최종 가격 (50% 하락)
        assert_eq!(prices[10], 25_000);
    }

    #[test]
    fn test_health_factor() {
        // 담보: $50,000, 대출: $25,000, CR 필요: 80%
        // 필요 담보: $25,000 * 80% = $20,000
        // 건강도: $50,000 / $20,000 * 100 = 250%
        let health = calculate_health_factor(50_000, 25_000, 80);
        assert_eq!(health, 250);
    }
}

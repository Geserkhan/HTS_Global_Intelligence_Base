use crate as pallet_stablecoin_lending;
use frame_support::{
    parameter_types,
    traits::{ConstU16, ConstU32, ConstU64},
    PalletId,
};
use frame_system::EnsureRoot;
use sp_core::H256;
use sp_runtime::{
    traits::{BlakeTwo256, IdentityLookup},
    BuildStorage,
};

// Mock 블록 타입 정의
type Block = frame_system::mocking::MockBlock<Test>;
type Balance = u128;

// 테스트용 Mock Runtime 구성
frame_support::construct_runtime!(
    pub enum Test
    {
        System: frame_system,
        Balances: pallet_balances,
        StablecoinLending: pallet_stablecoin_lending,
    }
);

// System Pallet 설정 파라미터
parameter_types! {
    pub const BlockHashCount: u64 = 250;
    pub const SS58Prefix: u16 = 42;
}

// System Pallet Config 구현
impl frame_system::Config for Test {
    type BaseCallFilter = frame_support::traits::Everything;
    type BlockWeights = ();
    type BlockLength = ();
    type DbWeight = ();
    type RuntimeOrigin = RuntimeOrigin;
    type RuntimeCall = RuntimeCall;
    type Nonce = u64;
    type Hash = H256;
    type Hashing = BlakeTwo256;
    type AccountId = u64;  // AccountId = u64
    type Lookup = IdentityLookup<Self::AccountId>;
    type Block = Block;
    type RuntimeEvent = RuntimeEvent;
    type BlockHashCount = BlockHashCount;
    type Version = ();
    type PalletInfo = PalletInfo;
    type AccountData = pallet_balances::AccountData<Balance>;
    type OnNewAccount = ();
    type OnKilledAccount = ();
    type SystemWeightInfo = ();
    type SS58Prefix = SS58Prefix;
    type OnSetCode = ();
    type MaxConsumers = ConstU32<16>;
}

// Balances Pallet 설정 파라미터
parameter_types! {
    pub const ExistentialDeposit: Balance = 1;
    pub const MaxLocks: u32 = 50;
    pub const MaxReserves: u32 = 50;
}

// Balances Pallet Config 구현
impl pallet_balances::Config for Test {
    type MaxLocks = MaxLocks;
    type MaxReserves = MaxReserves;
    type ReserveIdentifier = [u8; 8];
    type Balance = Balance;
    type RuntimeEvent = RuntimeEvent;
    type DustRemoval = ();
    type ExistentialDeposit = ExistentialDeposit;
    type AccountStore = System;
    type WeightInfo = ();
    type FreezeIdentifier = ();
    type MaxFreezes = ();
    type RuntimeHoldReason = ();
    type RuntimeFreezeReason = ();
}

// Stablecoin Lending Pallet 파라미터
parameter_types! {
    /// 최대 대출 수: 10,000개
    pub const MaxLoans: u32 = 10_000;
    /// 최소 담보율: 50% = 5,000 basis points
    pub const MinCollateralRatio: u32 = 5_000;
    /// 기본 담보율: 150% = 15,000 basis points
    pub const BaseCollateralRatio: u32 = 15_000;
    /// De-Risk 임계값: 145% = 14,500 basis points
    pub const DeRiskThreshold: u32 = 14_500;
    /// 부분 청산 임계값: 140% = 14,000 basis points
    pub const PartialLiquidationThreshold: u32 = 14_000;
    /// 긴급 청산 임계값: 140% = 14,000 basis points (미만 시 긴급 청산)
    pub const EmergencyThreshold: u32 = 14_000;
    /// 기본 이자율: 연 5% = 500 basis points
    pub const BaseInterestRate: u32 = 500;
    /// 청산 인센티브: 5% = 500 basis points
    pub const LiquidationIncentive: u32 = 500;
}

// Stablecoin Lending Pallet Config 구현
impl pallet_stablecoin_lending::Config for Test {
    type RuntimeEvent = RuntimeEvent;
    type Currency = Balances;
    type MaxLoans = MaxLoans;
    type MinCollateralRatio = MinCollateralRatio;
    type BaseCollateralRatio = BaseCollateralRatio;
    type DeRiskThreshold = DeRiskThreshold;
    type PartialLiquidationThreshold = PartialLiquidationThreshold;
    type EmergencyThreshold = EmergencyThreshold;
    type BaseInterestRate = BaseInterestRate;
    type LiquidationIncentive = LiquidationIncentive;
}

// Mock Runtime Genesis 설정을 기반으로 테스트 환경 빌드
pub fn new_test_ext() -> sp_io::TestExternalities {
    let mut t = frame_system::GenesisConfig::<Test>::default()
        .build_storage()
        .unwrap();

    // Balances Genesis 설정
    pallet_balances::GenesisConfig::<Test> {
        balances: vec![
            (ALICE, 1_000_000_000),
            (BOB, 1_000_000_000),
            (CHARLIE, 1_000_000_000),
            (DAVE, 1_000_000_000),
        ],
    }
    .assimilate_storage(&mut t)
    .unwrap();

    let mut ext = sp_io::TestExternalities::new(t);
    // 블록 번호를 1로 초기화 (블록 0은 Genesis)
    ext.execute_with(|| System::set_block_number(1));
    ext
}

// 테스트 헬퍼 함수 및 상수
#[cfg(test)]
mod test_helpers {
    use super::*;

    // 테스트 계정 ID
    pub const ALICE: u64 = 1;
    pub const BOB: u64 = 2;
    pub const CHARLIE: u64 = 3;
    pub const DAVE: u64 = 4;

    // 테스트 자산 ID
    pub const ETH: u32 = 1;
    pub const BTC: u32 = 2;

    // 테스트 금액 상수
    pub const ONE_ETH: u128 = 1_000_000_000_000_000_000; // 10^18
    pub const ONE_BTC: u128 = 100_000_000; // 10^8

    /// 블록을 특정 번호까지 진행시키는 헬퍼 함수
    pub fn run_to_block(n: u64) {
        while System::block_number() < n {
            if System::block_number() > 1 {
                StablecoinLending::on_finalize(System::block_number());
                System::on_finalize(System::block_number());
            }
            System::set_block_number(System::block_number() + 1);
            System::on_initialize(System::block_number());
            StablecoinLending::on_initialize(System::block_number());
        }
    }

    /// 자산 가격 설정 헬퍼 함수
    pub fn set_asset_price(asset_id: u32, price: u128) {
        assert!(StablecoinLending::update_asset_price(
            RuntimeOrigin::root(),
            asset_id,
            price
        )
        .is_ok());
    }

    /// 기여도 점수 설정 헬퍼 함수
    pub fn set_contribution_score(
        account: u64,
        lp: u32,
        tv: u32,
        gp: u32,
        hd: u32,
        ts: u32,
    ) {
        assert!(StablecoinLending::update_contribution_score(
            RuntimeOrigin::root(),
            account,
            lp,
            tv,
            gp,
            hd,
            ts
        )
        .is_ok());
    }

    /// 대출 실행 헬퍼 함수
    pub fn create_loan(
        who: u64,
        asset_id: u32,
        collateral_amount: u128,
        loan_amount: u128,
    ) -> Result<u64, sp_runtime::DispatchError> {
        StablecoinLending::execute_loan(
            RuntimeOrigin::signed(who),
            asset_id,
            collateral_amount,
            loan_amount,
        )?;

        // 마지막 대출 ID 반환
        Ok(StablecoinLending::loan_count() - 1)
    }

    /// 기본 CS 점수 설정 (모든 항목 50점)
    pub fn set_default_contribution_score(account: u64) {
        set_contribution_score(account, 50, 50, 50, 50, 50);
    }

    /// 높은 CS 점수 설정 (모든 항목 90점)
    pub fn set_high_contribution_score(account: u64) {
        set_contribution_score(account, 90, 90, 90, 90, 90);
    }

    /// 낮은 CS 점수 설정 (모든 항목 10점)
    pub fn set_low_contribution_score(account: u64) {
        set_contribution_score(account, 10, 10, 10, 10, 10);
    }
}

#[cfg(test)]
pub use test_helpers::*;

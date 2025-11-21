//! # Mock Runtime for Stablecoin Lending Pallet
//!
//! Oracle Governance 패턴을 따르는 테스트 환경을 제공합니다.

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

type Block = frame_system::mocking::MockBlock<Test>;

// Configure a mock runtime to test the pallet.
frame_support::construct_runtime!(
	pub enum Test
	{
		System: frame_system,
		StablecoinLending: pallet_stablecoin_lending,
	}
);

parameter_types! {
	pub const BlockHashCount: u64 = 250;
	pub const SS58Prefix: u16 = 42;
}

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
	type AccountId = u64;
	type Lookup = IdentityLookup<Self::AccountId>;
	type Block = Block;
	type RuntimeEvent = RuntimeEvent;
	type BlockHashCount = BlockHashCount;
	type Version = ();
	type PalletInfo = PalletInfo;
	type AccountData = ();
	type OnNewAccount = ();
	type OnKilledAccount = ();
	type SystemWeightInfo = ();
	type SS58Prefix = SS58Prefix;
	type OnSetCode = ();
	type MaxConsumers = ConstU32<16>;
}

parameter_types! {
	/// 최대 대출 금고 수
	pub const MaxLoans: u32 = 10_000;
	/// 최소 담보율 (50%)
	pub const MinCollateralRatio: u32 = 50;
	/// 기본 담보율 (150%)
	pub const BaseCollateralRatio: u32 = 150;
	/// 청산 페널티 (10%)
	pub const LiquidationPenalty: u32 = 10;
	/// 부분 청산 비율 (50%)
	pub const PartialLiquidationRatio: u32 = 50;
	/// 팔렛 ID
	pub const StablecoinLendingPalletId: PalletId = PalletId(*b"afe/hear");
	/// 최소 대출 금액
	pub const MinLoanAmount: u128 = 100_000_000; // 0.1 Stablecoin (assuming 9 decimals)
	/// 최대 대출 금액
	pub const MaxLoanAmount: u128 = 1_000_000_000_000_000; // 1M Stablecoin
}

impl pallet_stablecoin_lending::Config for Test {
	type RuntimeEvent = RuntimeEvent;
	type AdminOrigin = EnsureRoot<u64>;
	type MaxLoans = MaxLoans;
	type MinCollateralRatio = MinCollateralRatio;
	type BaseCollateralRatio = BaseCollateralRatio;
	type LiquidationPenalty = LiquidationPenalty;
	type PartialLiquidationRatio = PartialLiquidationRatio;
	type PalletId = StablecoinLendingPalletId;
	type MinLoanAmount = MinLoanAmount;
	type MaxLoanAmount = MaxLoanAmount;
}

/// 새 테스트 환경 생성
pub fn new_test_ext() -> sp_io::TestExternalities {
	let mut t = frame_system::GenesisConfig::<Test>::default().build_storage().unwrap();

	// Genesis 설정
	pallet_stablecoin_lending::GenesisConfig::<Test> {
		// 초기 자산 가격 설정
		// AssetId 1: BTC ($50,000.00, 6 decimals)
		// AssetId 2: ETH ($3,000.00, 6 decimals)
		// AssetId 3: DOT ($10.00, 6 decimals)
		initial_asset_prices: vec![
			(1, 50_000_000_000), // BTC: $50,000
			(2, 3_000_000_000),  // ETH: $3,000
			(3, 10_000_000),     // DOT: $10
		],
		// 초기 기여도 점수 설정
		// ALICE: CS = 80
		// BOB: CS = 50
		// CHARLIE: CS = 30
		initial_contribution_scores: vec![
			(ALICE, 80),
			(BOB, 50),
			(CHARLIE, 30),
		],
		_phantom: Default::default(),
	}
	.assimilate_storage(&mut t)
	.unwrap();

	let mut ext = sp_io::TestExternalities::new(t);
	ext.execute_with(|| System::set_block_number(1));
	ext
}

#[cfg(test)]
mod test_helpers {
	use super::*;

	/// 테스트 계정
	pub const ALICE: u64 = 1;
	pub const BOB: u64 = 2;
	pub const CHARLIE: u64 = 3;
	pub const DAVE: u64 = 4;
	pub const EVE: u64 = 5;

	/// 자산 ID
	pub const BTC_ASSET_ID: u32 = 1;
	pub const ETH_ASSET_ID: u32 = 2;
	pub const DOT_ASSET_ID: u32 = 3;

	/// 블록 진행
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

	/// 기여도 점수 설정
	pub fn set_contribution_score(account: u64, score: u32) {
		pallet_stablecoin_lending::ContributionScores::<Test>::insert(account, score);
	}

	/// 자산 가격 설정
	pub fn set_asset_price(asset_id: u32, price: u128) {
		pallet_stablecoin_lending::AssetPrices::<Test>::insert(asset_id, price);
	}

	/// 기여도 구성 요소 생성
	pub fn create_contribution_components(
		lp: u32,
		tv: u32,
		gp: u32,
		hd: u32,
		ts: u32,
	) -> pallet_stablecoin_lending::ContributionComponents {
		pallet_stablecoin_lending::ContributionComponents {
			liquidity_provision: lp,
			total_value_locked: tv,
			governance_participation: gp,
			historical_debt: hd,
			tenure_score: ts,
		}
	}
}

#[cfg(test)]
pub use test_helpers::*;

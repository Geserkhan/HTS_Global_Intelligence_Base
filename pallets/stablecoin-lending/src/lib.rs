//! # Pallet Stablecoin Lending (Heart)
//!
//! AFE Protocol의 핵심 스테이블코인 대출 팔렛입니다.
//!
//! ## 개요
//!
//! Heart 팔렛은 사용자의 기여도 점수(CS)를 기반으로 동적 담보율(CR_dynamic)을 계산하여
//! 스테이블코인 대출을 제공하는 시스템입니다.
//!
//! ## 핵심 공식
//!
//! ### 1. 기여도 점수 (Contribution Score, CS)
//! ```text
//! CS = 0.30 × LP + 0.25 × TV + 0.20 × GP + 0.15 × HD + 0.10 × TS
//! ```
//!
//! ### 2. 동적 담보율 (Dynamic Collateral Ratio)
//! ```text
//! CR_dynamic = 150% - CS (범위: 50%-150%)
//! ```
//!
//! ### 3. 최대 대출 금액
//! ```text
//! V_loan_max = V_collateral × 100 / CR_dynamic
//! ```
//!
//! ## 3단계 청산 방지 시스템
//!
//! - **Active** (≥ 150%): 정상 운영
//! - **DeRisk** (145%-150%): 차익거래 유도
//! - **PartialLiquid** (140%-145%): 부분 청산
//! - **EmergencyStop** (< 140%): 강제 청산

#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[cfg(test)]
mod mock;

#[cfg(test)]
mod tests;

use codec::{Decode, Encode, MaxEncodedLen};
use frame_support::{
	dispatch::DispatchResult,
	pallet_prelude::*,
	traits::{Get, UnixTime},
	PalletId,
};
use frame_system::pallet_prelude::*;
use scale_info::TypeInfo;
use sp_runtime::{
	traits::{AccountIdConversion, CheckedAdd, CheckedDiv, CheckedMul, CheckedSub, Saturating, Zero},
	ArithmeticError, Perbill, Percent, RuntimeDebug,
};
use sp_std::prelude::*;

/// 대출 금고 ID 타입
pub type LoanId = u64;

/// 자산 ID 타입 (예: RWA 토큰)
pub type AssetId = u32;

/// 기여도 점수 타입 (0-100)
pub type ContributionScore = u32;

/// 담보율 타입 (백분율, 50-150)
pub type CollateralRatio = u32;

/// 금고 상태
#[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
pub enum VaultStatus {
	/// 정상 상태 (담보율 ≥ 150%)
	Active,
	/// 1단계: 차익거래 유도 (담보율 145%-150%)
	DeRisk,
	/// 2단계: 부분 청산 (담보율 140%-145%)
	PartialLiquid,
	/// 3단계: 강제 청산 (담보율 < 140%)
	EmergencyStop,
}

impl Default for VaultStatus {
	fn default() -> Self {
		VaultStatus::Active
	}
}

/// 대출 금고 구조체
///
/// 사용자가 담보를 예치하고 스테이블코인을 대출받는 금고 정보를 저장합니다.
#[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
#[scale_info(skip_type_params(T))]
pub struct LoanVault<AccountId, Balance, BlockNumber> {
	/// 대출자 계정
	pub borrower: AccountId,
	/// 담보 자산 ID
	pub collateral_asset_id: AssetId,
	/// 담보 수량
	pub collateral_amount: Balance,
	/// 부채 금액 (대출받은 스테이블코인)
	pub debt_amount: Balance,
	/// 담보율 (백분율)
	pub collateral_ratio: CollateralRatio,
	/// 마지막 업데이트 블록
	pub last_update_block: BlockNumber,
	/// 금고 상태
	pub status: VaultStatus,
}

/// 청산 정보 구조체
#[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
pub struct LiquidationInfo<Balance> {
	/// 청산된 담보 금액
	pub liquidated_collateral: Balance,
	/// 상환된 부채 금액
	pub repaid_debt: Balance,
	/// 청산 페널티
	pub penalty: Balance,
}

/// 기여도 점수 구성 요소
#[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
pub struct ContributionComponents {
	/// LP (Liquidity Provision): 유동성 제공 점수 (0-100)
	pub liquidity_provision: u32,
	/// TV (Total Value Locked): 총 예치 가치 (0-100)
	pub total_value_locked: u32,
	/// GP (Governance Participation): 거버넌스 참여도 (0-100)
	pub governance_participation: u32,
	/// HD (Historical Debt): 과거 대출 이력 (0-100)
	pub historical_debt: u32,
	/// TS (Tenure Score): 재임 기간 점수 (0-100)
	pub tenure_score: u32,
}

impl Default for ContributionComponents {
	fn default() -> Self {
		Self {
			liquidity_provision: 0,
			total_value_locked: 0,
			governance_participation: 0,
			historical_debt: 0,
			tenure_score: 0,
		}
	}
}

/// 시스템 통계 구조체
#[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
pub struct SystemStats<Balance> {
	/// 총 발행된 스테이블코인
	pub total_supply: Balance,
	/// 총 담보 가치
	pub total_collateral_value: Balance,
	/// 활성 대출 수
	pub active_loans: u64,
	/// 총 청산 횟수
	pub total_liquidations: u64,
}

impl<Balance: Default> Default for SystemStats<Balance> {
	fn default() -> Self {
		Self {
			total_supply: Default::default(),
			total_collateral_value: Default::default(),
			active_loans: 0,
			total_liquidations: 0,
		}
	}
}

#[frame_support::pallet]
pub mod pallet {
	use super::*;

	#[pallet::pallet]
	pub struct Pallet<T>(_);

	/// 팔렛 설정 트레잇
	#[pallet::config]
	pub trait Config: frame_system::Config {
		/// 런타임 이벤트 타입
		type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;

		/// 관리자 권한 (오직 관리자만 특정 함수를 호출할 수 있음)
		type AdminOrigin: EnsureOrigin<Self::RuntimeOrigin>;

		/// 최대 대출 금고 수
		#[pallet::constant]
		type MaxLoans: Get<u32>;

		/// 최소 담보율 (기본값: 50%)
		#[pallet::constant]
		type MinCollateralRatio: Get<u32>;

		/// 기본 담보율 (기본값: 150%)
		#[pallet::constant]
		type BaseCollateralRatio: Get<u32>;

		/// 청산 페널티 비율 (기본값: 10%)
		#[pallet::constant]
		type LiquidationPenalty: Get<u32>;

		/// 부분 청산 비율 (기본값: 50%)
		#[pallet::constant]
		type PartialLiquidationRatio: Get<u32>;

		/// 팔렛 ID (treasury 주소 생성용)
		#[pallet::constant]
		type PalletId: Get<PalletId>;

		/// 최소 대출 금액
		#[pallet::constant]
		type MinLoanAmount: Get<u128>;

		/// 최대 대출 금액
		#[pallet::constant]
		type MaxLoanAmount: Get<u128>;
	}

	/// 대출 금고 저장소
	///
	/// LoanId => LoanVault 매핑
	#[pallet::storage]
	#[pallet::getter(fn vaults)]
	pub type Vaults<T: Config> = StorageMap<
		_,
		Blake2_128Concat,
		LoanId,
		LoanVault<T::AccountId, u128, BlockNumberFor<T>>,
		OptionQuery,
	>;

	/// 사용자별 대출 ID 목록
	///
	/// AccountId => Vec<LoanId>
	#[pallet::storage]
	#[pallet::getter(fn user_loans)]
	pub type UserLoans<T: Config> =
		StorageMap<_, Blake2_128Concat, T::AccountId, BoundedVec<LoanId, T::MaxLoans>, ValueQuery>;

	/// 기여도 점수 저장소
	///
	/// AccountId => ContributionScore (0-100)
	#[pallet::storage]
	#[pallet::getter(fn contribution_scores)]
	pub type ContributionScores<T: Config> =
		StorageMap<_, Blake2_128Concat, T::AccountId, ContributionScore, ValueQuery>;

	/// 기여도 점수 구성 요소 저장소
	///
	/// AccountId => ContributionComponents
	#[pallet::storage]
	#[pallet::getter(fn contribution_components)]
	pub type ContributionComponentsStorage<T: Config> =
		StorageMap<_, Blake2_128Concat, T::AccountId, ContributionComponents, ValueQuery>;

	/// 총 대출 수 (다음 대출 ID로 사용)
	#[pallet::storage]
	#[pallet::getter(fn loan_count)]
	pub type LoanCount<T: Config> = StorageValue<_, LoanId, ValueQuery>;

	/// 총 발행된 스테이블코인
	#[pallet::storage]
	#[pallet::getter(fn total_supply)]
	pub type TotalSupply<T: Config> = StorageValue<_, u128, ValueQuery>;

	/// 총 담보 가치 (USD 기준)
	#[pallet::storage]
	#[pallet::getter(fn total_collateral_value)]
	pub type TotalCollateralValue<T: Config> = StorageValue<_, u128, ValueQuery>;

	/// 자산별 가격 (USD, 6 decimals)
	///
	/// AssetId => Price (예: 2000_000000 = $2000.00)
	/// 실제 환경에서는 Brain (Oracle) 팔렛에서 가져옴
	#[pallet::storage]
	#[pallet::getter(fn asset_prices)]
	pub type AssetPrices<T: Config> = StorageMap<_, Blake2_128Concat, AssetId, u128, ValueQuery>;

	/// 시스템 통계
	#[pallet::storage]
	#[pallet::getter(fn system_stats)]
	pub type SystemStatsStorage<T: Config> = StorageValue<_, SystemStats<u128>, ValueQuery>;

	/// 청산자 보상 비율 (기본값: 5%)
	#[pallet::storage]
	#[pallet::getter(fn liquidator_reward_ratio)]
	pub type LiquidatorRewardRatio<T: Config> = StorageValue<_, u32, ValueQuery>;

	/// Genesis 설정
	#[pallet::genesis_config]
	#[derive(frame_support::DefaultNoBound)]
	pub struct GenesisConfig<T: Config> {
		/// 초기 자산 가격 설정
		pub initial_asset_prices: Vec<(AssetId, u128)>,
		/// 초기 기여도 점수 설정
		pub initial_contribution_scores: Vec<(T::AccountId, ContributionScore)>,
		#[serde(skip)]
		pub _phantom: PhantomData<T>,
	}

	#[pallet::genesis_build]
	impl<T: Config> BuildGenesisConfig for GenesisConfig<T> {
		fn build(&self) {
			// 초기 자산 가격 설정
			for (asset_id, price) in &self.initial_asset_prices {
				AssetPrices::<T>::insert(asset_id, price);
			}

			// 초기 기여도 점수 설정
			for (account, score) in &self.initial_contribution_scores {
				ContributionScores::<T>::insert(account, score);
			}

			// 초기 청산자 보상 비율 설정 (5%)
			LiquidatorRewardRatio::<T>::put(5u32);
		}
	}

	#[pallet::event]
	#[pallet::generate_deposit(pub(super) fn deposit_event)]
	pub enum Event<T: Config> {
		/// 대출 발행됨
		/// [loan_id, borrower, collateral_amount, loan_amount, collateral_ratio]
		LoanIssued {
			loan_id: LoanId,
			borrower: T::AccountId,
			collateral_amount: u128,
			loan_amount: u128,
			collateral_ratio: CollateralRatio,
		},
		/// 대출 상환됨
		/// [loan_id, amount]
		LoanRepaid { loan_id: LoanId, amount: u128 },
		/// 담보 추가됨
		/// [loan_id, amount]
		CollateralAdded { loan_id: LoanId, amount: u128 },
		/// 담보 인출됨
		/// [loan_id, amount]
		CollateralWithdrawn { loan_id: LoanId, amount: u128 },
		/// 금고 상태 변경됨
		/// [loan_id, old_status, new_status]
		VaultStatusChanged { loan_id: LoanId, old_status: VaultStatus, new_status: VaultStatus },
		/// 부분 청산 실행됨
		/// [loan_id, liquidated_amount]
		PartialLiquidation { loan_id: LoanId, liquidated_amount: u128 },
		/// 강제 청산 실행됨
		/// [loan_id]
		EmergencyLiquidation { loan_id: LoanId },
		/// 대출 금고 폐쇄됨
		/// [loan_id]
		VaultClosed { loan_id: LoanId },
		/// 기여도 점수 업데이트됨
		/// [account, old_score, new_score]
		ContributionScoreUpdated { account: T::AccountId, old_score: u32, new_score: u32 },
		/// 기여도 구성 요소 업데이트됨
		/// [account]
		ContributionComponentsUpdated { account: T::AccountId },
		/// 자산 가격 업데이트됨
		/// [asset_id, old_price, new_price]
		AssetPriceUpdated { asset_id: AssetId, old_price: u128, new_price: u128 },
		/// 청산자 보상 지급됨
		/// [liquidator, loan_id, reward_amount]
		LiquidatorRewarded { liquidator: T::AccountId, loan_id: LoanId, reward_amount: u128 },
		/// 시스템 통계 업데이트됨
		SystemStatsUpdated,
	}

	#[pallet::error]
	pub enum Error<T> {
		/// 담보가 불충분합니다
		InsufficientCollateral,
		/// 금고를 찾을 수 없습니다
		VaultNotFound,
		/// 유효하지 않은 대출 금액입니다
		InvalidLoanAmount,
		/// 산술 오버플로우 발생
		ArithmeticError,
		/// 시스템 리스크가 너무 높습니다
		SystemRiskTooHigh,
		/// 권한이 없습니다
		Unauthorized,
		/// 최대 대출 수 초과
		TooManyLoans,
		/// 유효하지 않은 담보율입니다
		InvalidCollateralRatio,
		/// 금고가 이미 청산 중입니다
		VaultUnderLiquidation,
		/// 대출 금액이 최소값보다 작습니다
		LoanAmountTooSmall,
		/// 대출 금액이 최대값보다 큽니다
		LoanAmountTooLarge,
		/// 담보 인출 불가 (담보율 부족)
		CannotWithdrawCollateral,
		/// 상환 금액이 부채보다 큽니다
		RepaymentExceedsDebt,
		/// 유효하지 않은 자산 ID입니다
		InvalidAssetId,
		/// 가격 정보를 찾을 수 없습니다
		PriceNotFound,
		/// 유효하지 않은 기여도 점수입니다
		InvalidContributionScore,
		/// 금고가 활성 상태가 아닙니다
		VaultNotActive,
		/// 청산 불가능한 금고입니다
		VaultNotLiquidatable,
	}

	#[pallet::hooks]
	impl<T: Config> Hooks<BlockNumberFor<T>> for Pallet<T> {
		/// 블록 초기화 시 모든 금고의 상태를 모니터링합니다
		fn on_initialize(_n: BlockNumberFor<T>) -> Weight {
			Self::monitor_all_vaults();
			Weight::from_parts(10_000, 0)
		}
	}

	#[pallet::call]
	impl<T: Config> Pallet<T> {
		/// 대출 실행
		///
		/// 담보를 예치하고 스테이블코인을 대출받습니다.
		///
		/// # 매개변수
		/// - `origin`: 대출자
		/// - `asset_id`: 담보 자산 ID
		/// - `collateral_amount`: 담보 수량
		/// - `loan_amount`: 대출 금액
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `LoanIssued`: 대출 발행 시
		#[pallet::call_index(0)]
		#[pallet::weight(10_000)]
		pub fn execute_loan(
			origin: OriginFor<T>,
			asset_id: AssetId,
			collateral_amount: u128,
			loan_amount: u128,
		) -> DispatchResult {
			let borrower = ensure_signed(origin)?;

			// 대출 금액 검증
			ensure!(loan_amount >= T::MinLoanAmount::get(), Error::<T>::LoanAmountTooSmall);
			ensure!(loan_amount <= T::MaxLoanAmount::get(), Error::<T>::LoanAmountTooLarge);

			// 최대 대출 수 확인
			let user_loans = UserLoans::<T>::get(&borrower);
			ensure!(
				user_loans.len() < T::MaxLoans::get() as usize,
				Error::<T>::TooManyLoans
			);

			// TODO: Brain (Oracle Governance) 연동
			// let adjusted_price = T::RiskManager::get_adjusted_price(asset_id)?;
			// 현재는 저장된 가격 사용 (모의 데이터)
			let asset_price = AssetPrices::<T>::get(asset_id);
			ensure!(asset_price > 0, Error::<T>::PriceNotFound);

			// TODO: Shield (ZK Verification) 연동
			// ensure!(T::TrustVerifier::has_valid_ltv_proof(&borrower), Error::<T>::LtvProofNotFound);

			// 기여도 점수(CS) 조회
			let cs = ContributionScores::<T>::get(&borrower);

			// 동적 담보율(CR_dynamic) 계산
			let cr_dynamic = Self::calculate_dynamic_collateral_ratio(
				cs,
				T::BaseCollateralRatio::get(),
				T::MinCollateralRatio::get(),
			);

			// 담보 가치 계산 (USD 기준)
			let collateral_value = collateral_amount
				.checked_mul(asset_price)
				.ok_or(Error::<T>::ArithmeticError)?
				.checked_div(1_000_000) // 가격은 6 decimals
				.ok_or(Error::<T>::ArithmeticError)?;

			// 최대 대출 금액 계산
			// V_loan_max = V_collateral × 100 / CR_dynamic
			let max_loan = collateral_value
				.checked_mul(100)
				.ok_or(Error::<T>::ArithmeticError)?
				.checked_div(cr_dynamic as u128)
				.ok_or(Error::<T>::ArithmeticError)?;

			// 대출 가능 여부 확인
			ensure!(loan_amount <= max_loan, Error::<T>::InsufficientCollateral);

			// 대출 ID 생성
			let loan_id = LoanCount::<T>::get();
			let current_block = <frame_system::Pallet<T>>::block_number();

			// LoanVault 생성
			let vault = LoanVault {
				borrower: borrower.clone(),
				collateral_asset_id: asset_id,
				collateral_amount,
				debt_amount: loan_amount,
				collateral_ratio: cr_dynamic,
				last_update_block: current_block,
				status: VaultStatus::Active,
			};

			// 저장소 업데이트
			Vaults::<T>::insert(loan_id, vault);
			UserLoans::<T>::try_mutate(&borrower, |loans| -> DispatchResult {
				loans.try_push(loan_id).map_err(|_| Error::<T>::TooManyLoans)?;
				Ok(())
			})?;

			// 대출 카운터 증가
			LoanCount::<T>::put(loan_id.saturating_add(1));

			// 총 공급량 증가
			TotalSupply::<T>::mutate(|supply| *supply = supply.saturating_add(loan_amount));

			// 총 담보 가치 증가
			TotalCollateralValue::<T>::mutate(|value| {
				*value = value.saturating_add(collateral_value)
			});

			// 시스템 통계 업데이트
			SystemStatsStorage::<T>::mutate(|stats| {
				stats.total_supply = stats.total_supply.saturating_add(loan_amount);
				stats.total_collateral_value =
					stats.total_collateral_value.saturating_add(collateral_value);
				stats.active_loans = stats.active_loans.saturating_add(1);
			});

			// 이벤트 발행
			Self::deposit_event(Event::LoanIssued {
				loan_id,
				borrower,
				collateral_amount,
				loan_amount,
				collateral_ratio: cr_dynamic,
			});

			Ok(())
		}

		/// 대출 상환
		///
		/// 스테이블코인을 상환하여 부채를 줄입니다.
		///
		/// # 매개변수
		/// - `origin`: 상환자 (대출자 또는 제3자)
		/// - `loan_id`: 대출 ID
		/// - `amount`: 상환 금액
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `LoanRepaid`: 대출 상환 시
		/// - `VaultClosed`: 금고 폐쇄 시
		#[pallet::call_index(1)]
		#[pallet::weight(10_000)]
		pub fn repay_loan(
			origin: OriginFor<T>,
			loan_id: LoanId,
			amount: u128,
		) -> DispatchResult {
			let _repayer = ensure_signed(origin)?;

			// 금고 조회
			let mut vault = Vaults::<T>::get(loan_id).ok_or(Error::<T>::VaultNotFound)?;

			// 상환 금액 검증
			ensure!(amount <= vault.debt_amount, Error::<T>::RepaymentExceedsDebt);

			// 부채 감소
			vault.debt_amount = vault.debt_amount.saturating_sub(amount);
			vault.last_update_block = <frame_system::Pallet<T>>::block_number();

			// 총 공급량 감소
			TotalSupply::<T>::mutate(|supply| *supply = supply.saturating_sub(amount));

			// 시스템 통계 업데이트
			SystemStatsStorage::<T>::mutate(|stats| {
				stats.total_supply = stats.total_supply.saturating_sub(amount);
			});

			// 부채가 0이 되면 금고 폐쇄
			if vault.debt_amount == 0 {
				// 사용자 대출 목록에서 제거
				UserLoans::<T>::mutate(&vault.borrower, |loans| {
					loans.retain(|&id| id != loan_id);
				});

				// 총 담보 가치 감소
				let asset_price = AssetPrices::<T>::get(vault.collateral_asset_id);
				let collateral_value = vault
					.collateral_amount
					.saturating_mul(asset_price)
					.saturating_div(1_000_000);
				TotalCollateralValue::<T>::mutate(|value| {
					*value = value.saturating_sub(collateral_value)
				});

				// 시스템 통계 업데이트
				SystemStatsStorage::<T>::mutate(|stats| {
					stats.total_collateral_value =
						stats.total_collateral_value.saturating_sub(collateral_value);
					stats.active_loans = stats.active_loans.saturating_sub(1);
				});

				// 금고 삭제
				Vaults::<T>::remove(loan_id);

				Self::deposit_event(Event::VaultClosed { loan_id });
			} else {
				// 금고 업데이트
				Vaults::<T>::insert(loan_id, vault);
			}

			// 이벤트 발행
			Self::deposit_event(Event::LoanRepaid { loan_id, amount });

			Ok(())
		}

		/// 담보 추가
		///
		/// 금고에 추가 담보를 예치하여 담보율을 개선합니다.
		///
		/// # 매개변수
		/// - `origin`: 예치자 (대출자 또는 제3자)
		/// - `loan_id`: 대출 ID
		/// - `amount`: 추가 담보 수량
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `CollateralAdded`: 담보 추가 시
		/// - `VaultStatusChanged`: 금고 상태 변경 시
		#[pallet::call_index(2)]
		#[pallet::weight(10_000)]
		pub fn add_collateral(
			origin: OriginFor<T>,
			loan_id: LoanId,
			amount: u128,
		) -> DispatchResult {
			let _depositor = ensure_signed(origin)?;

			// 금고 조회
			let mut vault = Vaults::<T>::get(loan_id).ok_or(Error::<T>::VaultNotFound)?;

			// 담보 증가
			vault.collateral_amount = vault.collateral_amount.saturating_add(amount);
			vault.last_update_block = <frame_system::Pallet<T>>::block_number();

			// 총 담보 가치 증가
			let asset_price = AssetPrices::<T>::get(vault.collateral_asset_id);
			let added_value = amount.saturating_mul(asset_price).saturating_div(1_000_000);
			TotalCollateralValue::<T>::mutate(|value| *value = value.saturating_add(added_value));

			// 시스템 통계 업데이트
			SystemStatsStorage::<T>::mutate(|stats| {
				stats.total_collateral_value =
					stats.total_collateral_value.saturating_add(added_value);
			});

			// 금고 상태 재평가
			let old_status = vault.status.clone();
			let current_cr = Self::calculate_current_collateral_ratio(&vault)?;
			vault.status = Self::determine_vault_status(current_cr);

			// 금고 업데이트
			Vaults::<T>::insert(loan_id, vault.clone());

			// 이벤트 발행
			Self::deposit_event(Event::CollateralAdded { loan_id, amount });

			if old_status != vault.status {
				Self::deposit_event(Event::VaultStatusChanged {
					loan_id,
					old_status,
					new_status: vault.status,
				});
			}

			Ok(())
		}

		/// 담보 인출
		///
		/// 금고에서 담보를 인출합니다. 담보율이 안전 범위 내에 있어야 합니다.
		///
		/// # 매개변수
		/// - `origin`: 대출자
		/// - `loan_id`: 대출 ID
		/// - `amount`: 인출 담보 수량
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `CollateralWithdrawn`: 담보 인출 시
		#[pallet::call_index(3)]
		#[pallet::weight(10_000)]
		pub fn withdraw_collateral(
			origin: OriginFor<T>,
			loan_id: LoanId,
			amount: u128,
		) -> DispatchResult {
			let withdrawer = ensure_signed(origin)?;

			// 금고 조회
			let mut vault = Vaults::<T>::get(loan_id).ok_or(Error::<T>::VaultNotFound)?;

			// 대출자 확인
			ensure!(vault.borrower == withdrawer, Error::<T>::Unauthorized);

			// 담보 인출 후 잔액 확인
			let remaining_collateral =
				vault.collateral_amount.checked_sub(amount).ok_or(Error::<T>::ArithmeticError)?;

			// 인출 후 담보율 계산
			let asset_price = AssetPrices::<T>::get(vault.collateral_asset_id);
			let remaining_collateral_value =
				remaining_collateral.saturating_mul(asset_price).saturating_div(1_000_000);

			// 인출 후 담보율 = (remaining_collateral_value / debt_amount) × 100
			let after_cr = if vault.debt_amount > 0 {
				remaining_collateral_value
					.saturating_mul(100)
					.saturating_div(vault.debt_amount)
			} else {
				u128::MAX
			};

			// 최소 담보율(150%) 이상 유지해야 함
			ensure!(
				after_cr >= T::BaseCollateralRatio::get() as u128,
				Error::<T>::CannotWithdrawCollateral
			);

			// 담보 감소
			vault.collateral_amount = remaining_collateral;
			vault.last_update_block = <frame_system::Pallet<T>>::block_number();

			// 총 담보 가치 감소
			let withdrawn_value = amount.saturating_mul(asset_price).saturating_div(1_000_000);
			TotalCollateralValue::<T>::mutate(|value| {
				*value = value.saturating_sub(withdrawn_value)
			});

			// 시스템 통계 업데이트
			SystemStatsStorage::<T>::mutate(|stats| {
				stats.total_collateral_value =
					stats.total_collateral_value.saturating_sub(withdrawn_value);
			});

			// 금고 업데이트
			Vaults::<T>::insert(loan_id, vault);

			// 이벤트 발행
			Self::deposit_event(Event::CollateralWithdrawn { loan_id, amount });

			Ok(())
		}

		/// 부분 청산
		///
		/// 담보율이 140%-145% 범위에 있는 금고의 일부를 청산합니다.
		///
		/// # 매개변수
		/// - `origin`: 청산자
		/// - `loan_id`: 대출 ID
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `PartialLiquidation`: 부분 청산 실행 시
		/// - `LiquidatorRewarded`: 청산자 보상 지급 시
		#[pallet::call_index(4)]
		#[pallet::weight(10_000)]
		pub fn partial_liquidate(origin: OriginFor<T>, loan_id: LoanId) -> DispatchResult {
			let liquidator = ensure_signed(origin)?;

			// 금고 조회
			let mut vault = Vaults::<T>::get(loan_id).ok_or(Error::<T>::VaultNotFound)?;

			// 부분 청산 가능한 상태인지 확인
			ensure!(vault.status == VaultStatus::PartialLiquid, Error::<T>::VaultNotLiquidatable);

			// 부분 청산 비율 (기본값: 50%)
			let liquidation_ratio = T::PartialLiquidationRatio::get();

			// 청산할 부채 금액
			let liquidated_debt =
				vault.debt_amount.saturating_mul(liquidation_ratio as u128).saturating_div(100);

			// 청산할 담보 금액 (청산 페널티 포함)
			let penalty_ratio = T::LiquidationPenalty::get();
			let total_ratio = 100u32.saturating_add(penalty_ratio);

			let asset_price = AssetPrices::<T>::get(vault.collateral_asset_id);
			let liquidated_collateral_value = liquidated_debt
				.saturating_mul(total_ratio as u128)
				.saturating_div(100);
			let liquidated_collateral = liquidated_collateral_value
				.saturating_mul(1_000_000)
				.saturating_div(asset_price);

			// 청산자 보상 계산 (청산 페널티의 일부)
			let liquidator_reward_ratio = LiquidatorRewardRatio::<T>::get();
			let liquidator_reward =
				liquidated_debt.saturating_mul(liquidator_reward_ratio as u128).saturating_div(100);

			// 금고 업데이트
			vault.debt_amount = vault.debt_amount.saturating_sub(liquidated_debt);
			vault.collateral_amount = vault.collateral_amount.saturating_sub(liquidated_collateral);
			vault.last_update_block = <frame_system::Pallet<T>>::block_number();

			// 금고 상태 재평가
			let current_cr = Self::calculate_current_collateral_ratio(&vault)?;
			vault.status = Self::determine_vault_status(current_cr);

			// 금고 업데이트
			Vaults::<T>::insert(loan_id, vault);

			// 총 공급량 감소
			TotalSupply::<T>::mutate(|supply| *supply = supply.saturating_sub(liquidated_debt));

			// 총 담보 가치 감소
			TotalCollateralValue::<T>::mutate(|value| {
				*value = value.saturating_sub(liquidated_collateral_value)
			});

			// 시스템 통계 업데이트
			SystemStatsStorage::<T>::mutate(|stats| {
				stats.total_supply = stats.total_supply.saturating_sub(liquidated_debt);
				stats.total_collateral_value =
					stats.total_collateral_value.saturating_sub(liquidated_collateral_value);
				stats.total_liquidations = stats.total_liquidations.saturating_add(1);
			});

			// 이벤트 발행
			Self::deposit_event(Event::PartialLiquidation {
				loan_id,
				liquidated_amount: liquidated_debt,
			});
			Self::deposit_event(Event::LiquidatorRewarded {
				liquidator,
				loan_id,
				reward_amount: liquidator_reward,
			});

			Ok(())
		}

		/// 강제 청산
		///
		/// 담보율이 140% 미만인 금고를 강제로 청산합니다.
		///
		/// # 매개변수
		/// - `origin`: 청산자
		/// - `loan_id`: 대출 ID
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `EmergencyLiquidation`: 강제 청산 실행 시
		/// - `VaultClosed`: 금고 폐쇄 시
		/// - `LiquidatorRewarded`: 청산자 보상 지급 시
		#[pallet::call_index(5)]
		#[pallet::weight(10_000)]
		pub fn emergency_liquidate(origin: OriginFor<T>, loan_id: LoanId) -> DispatchResult {
			let liquidator = ensure_signed(origin)?;

			// 금고 조회
			let vault = Vaults::<T>::get(loan_id).ok_or(Error::<T>::VaultNotFound)?;

			// 강제 청산 가능한 상태인지 확인
			ensure!(
				vault.status == VaultStatus::EmergencyStop,
				Error::<T>::VaultNotLiquidatable
			);

			// 청산자 보상 계산
			let liquidator_reward_ratio = LiquidatorRewardRatio::<T>::get();
			let liquidator_reward =
				vault.debt_amount.saturating_mul(liquidator_reward_ratio as u128).saturating_div(100);

			// 사용자 대출 목록에서 제거
			UserLoans::<T>::mutate(&vault.borrower, |loans| {
				loans.retain(|&id| id != loan_id);
			});

			// 총 공급량 감소
			TotalSupply::<T>::mutate(|supply| *supply = supply.saturating_sub(vault.debt_amount));

			// 총 담보 가치 감소
			let asset_price = AssetPrices::<T>::get(vault.collateral_asset_id);
			let collateral_value = vault
				.collateral_amount
				.saturating_mul(asset_price)
				.saturating_div(1_000_000);
			TotalCollateralValue::<T>::mutate(|value| {
				*value = value.saturating_sub(collateral_value)
			});

			// 시스템 통계 업데이트
			SystemStatsStorage::<T>::mutate(|stats| {
				stats.total_supply = stats.total_supply.saturating_sub(vault.debt_amount);
				stats.total_collateral_value =
					stats.total_collateral_value.saturating_sub(collateral_value);
				stats.active_loans = stats.active_loans.saturating_sub(1);
				stats.total_liquidations = stats.total_liquidations.saturating_add(1);
			});

			// 금고 삭제
			Vaults::<T>::remove(loan_id);

			// 이벤트 발행
			Self::deposit_event(Event::EmergencyLiquidation { loan_id });
			Self::deposit_event(Event::VaultClosed { loan_id });
			Self::deposit_event(Event::LiquidatorRewarded {
				liquidator,
				loan_id,
				reward_amount: liquidator_reward,
			});

			Ok(())
		}

		/// 기여도 점수 업데이트 (관리자 전용)
		///
		/// 사용자의 기여도 점수를 수동으로 업데이트합니다.
		///
		/// # 매개변수
		/// - `origin`: 관리자
		/// - `account`: 대상 계정
		/// - `score`: 새 기여도 점수 (0-100)
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `ContributionScoreUpdated`: 기여도 점수 업데이트 시
		#[pallet::call_index(6)]
		#[pallet::weight(10_000)]
		pub fn update_contribution_score(
			origin: OriginFor<T>,
			account: T::AccountId,
			score: u32,
		) -> DispatchResult {
			T::AdminOrigin::ensure_origin(origin)?;

			// 점수 범위 검증 (0-100)
			ensure!(score <= 100, Error::<T>::InvalidContributionScore);

			// 기존 점수 조회
			let old_score = ContributionScores::<T>::get(&account);

			// 새 점수 저장
			ContributionScores::<T>::insert(&account, score);

			// 이벤트 발행
			Self::deposit_event(Event::ContributionScoreUpdated { account, old_score, new_score: score });

			Ok(())
		}

		/// 기여도 구성 요소 업데이트 (관리자 전용)
		///
		/// 사용자의 기여도 구성 요소를 업데이트하고 CS를 자동 계산합니다.
		///
		/// # 매개변수
		/// - `origin`: 관리자
		/// - `account`: 대상 계정
		/// - `components`: 기여도 구성 요소
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `ContributionComponentsUpdated`: 기여도 구성 요소 업데이트 시
		/// - `ContributionScoreUpdated`: 기여도 점수 업데이트 시
		#[pallet::call_index(7)]
		#[pallet::weight(10_000)]
		pub fn update_contribution_components(
			origin: OriginFor<T>,
			account: T::AccountId,
			components: ContributionComponents,
		) -> DispatchResult {
			T::AdminOrigin::ensure_origin(origin)?;

			// 각 구성 요소 범위 검증 (0-100)
			ensure!(components.liquidity_provision <= 100, Error::<T>::InvalidContributionScore);
			ensure!(components.total_value_locked <= 100, Error::<T>::InvalidContributionScore);
			ensure!(
				components.governance_participation <= 100,
				Error::<T>::InvalidContributionScore
			);
			ensure!(components.historical_debt <= 100, Error::<T>::InvalidContributionScore);
			ensure!(components.tenure_score <= 100, Error::<T>::InvalidContributionScore);

			// CS 계산
			let cs = Self::calculate_contribution_score(
				components.liquidity_provision,
				components.total_value_locked,
				components.governance_participation,
				components.historical_debt,
				components.tenure_score,
			);

			// 기존 점수 조회
			let old_score = ContributionScores::<T>::get(&account);

			// 구성 요소 및 점수 저장
			ContributionComponentsStorage::<T>::insert(&account, components);
			ContributionScores::<T>::insert(&account, cs);

			// 이벤트 발행
			Self::deposit_event(Event::ContributionComponentsUpdated { account: account.clone() });
			Self::deposit_event(Event::ContributionScoreUpdated {
				account,
				old_score,
				new_score: cs,
			});

			Ok(())
		}

		/// 자산 가격 업데이트 (관리자 전용)
		///
		/// 자산의 가격을 업데이트합니다.
		/// 실제 환경에서는 Brain (Oracle) 팔렛에서 자동으로 가져옵니다.
		///
		/// # 매개변수
		/// - `origin`: 관리자
		/// - `asset_id`: 자산 ID
		/// - `price`: 새 가격 (USD, 6 decimals)
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		///
		/// # 이벤트
		/// - `AssetPriceUpdated`: 자산 가격 업데이트 시
		#[pallet::call_index(8)]
		#[pallet::weight(10_000)]
		pub fn update_asset_price(
			origin: OriginFor<T>,
			asset_id: AssetId,
			price: u128,
		) -> DispatchResult {
			T::AdminOrigin::ensure_origin(origin)?;

			// 가격 검증
			ensure!(price > 0, Error::<T>::InvalidAssetId);

			// 기존 가격 조회
			let old_price = AssetPrices::<T>::get(asset_id);

			// 새 가격 저장
			AssetPrices::<T>::insert(asset_id, price);

			// 이벤트 발행
			Self::deposit_event(Event::AssetPriceUpdated { asset_id, old_price, new_price: price });

			Ok(())
		}

		/// 청산자 보상 비율 설정 (관리자 전용)
		///
		/// 청산자가 받는 보상 비율을 설정합니다.
		///
		/// # 매개변수
		/// - `origin`: 관리자
		/// - `ratio`: 보상 비율 (백분율, 예: 5 = 5%)
		///
		/// # 반환값
		/// - `DispatchResult`: 성공 또는 오류
		#[pallet::call_index(9)]
		#[pallet::weight(10_000)]
		pub fn set_liquidator_reward_ratio(origin: OriginFor<T>, ratio: u32) -> DispatchResult {
			T::AdminOrigin::ensure_origin(origin)?;

			// 보상 비율 범위 검증 (0-20%)
			ensure!(ratio <= 20, Error::<T>::InvalidCollateralRatio);

			// 새 비율 저장
			LiquidatorRewardRatio::<T>::put(ratio);

			Ok(())
		}
	}
}

impl<T: Config> Pallet<T> {
	/// 기여도 점수 계산
	///
	/// CS = 0.30 × LP + 0.25 × TV + 0.20 × GP + 0.15 × HD + 0.10 × TS
	///
	/// # 매개변수
	/// - `liquidity_provision`: LP (Liquidity Provision) 점수 (0-100)
	/// - `total_value_locked`: TV (Total Value Locked) 점수 (0-100)
	/// - `governance_participation`: GP (Governance Participation) 점수 (0-100)
	/// - `historical_debt`: HD (Historical Debt) 점수 (0-100)
	/// - `tenure_score`: TS (Tenure Score) 점수 (0-100)
	///
	/// # 반환값
	/// - `u32`: 기여도 점수 (0-100)
	pub fn calculate_contribution_score(
		liquidity_provision: u32,
		total_value_locked: u32,
		governance_participation: u32,
		historical_debt: u32,
		tenure_score: u32,
	) -> u32 {
		// CS = 0.30LP + 0.25TV + 0.20GP + 0.15HD + 0.10TS
		let cs = liquidity_provision
			.saturating_mul(30)
			.saturating_div(100)
			.saturating_add(total_value_locked.saturating_mul(25).saturating_div(100))
			.saturating_add(governance_participation.saturating_mul(20).saturating_div(100))
			.saturating_add(historical_debt.saturating_mul(15).saturating_div(100))
			.saturating_add(tenure_score.saturating_mul(10).saturating_div(100));

		// 최대 100으로 제한
		cs.min(100)
	}

	/// 동적 담보율 계산
	///
	/// CR_dynamic = BaseCollateralRatio - CS (범위: MinCollateralRatio - BaseCollateralRatio)
	///
	/// # 매개변수
	/// - `contribution_score`: 기여도 점수 (0-100)
	/// - `base_ratio`: 기본 담보율 (기본값: 150%)
	/// - `min_ratio`: 최소 담보율 (기본값: 50%)
	///
	/// # 반환값
	/// - `u32`: 동적 담보율 (백분율)
	pub fn calculate_dynamic_collateral_ratio(
		contribution_score: u32,
		base_ratio: u32,
		min_ratio: u32,
	) -> u32 {
		// CR_dynamic = 150% - CS
		let ratio = base_ratio.saturating_sub(contribution_score);

		// 범위 제한: 50%-150%
		ratio.max(min_ratio).min(base_ratio)
	}

	/// 현재 담보율 계산
	///
	/// 금고의 현재 담보율을 계산합니다.
	///
	/// # 매개변수
	/// - `vault`: 대출 금고
	///
	/// # 반환값
	/// - `Result<u32, DispatchError>`: 현재 담보율 또는 오류
	pub fn calculate_current_collateral_ratio(
		vault: &LoanVault<T::AccountId, u128, BlockNumberFor<T>>,
	) -> Result<u32, DispatchError> {
		// 부채가 0이면 담보율 최대값 반환
		if vault.debt_amount == 0 {
			return Ok(u32::MAX)
		}

		// 담보 가치 계산
		let asset_price = AssetPrices::<T>::get(vault.collateral_asset_id);
		let collateral_value = vault
			.collateral_amount
			.checked_mul(asset_price)
			.ok_or(Error::<T>::ArithmeticError)?
			.checked_div(1_000_000)
			.ok_or(Error::<T>::ArithmeticError)?;

		// 현재 담보율 = (collateral_value / debt_amount) × 100
		let current_cr = collateral_value
			.checked_mul(100)
			.ok_or(Error::<T>::ArithmeticError)?
			.checked_div(vault.debt_amount)
			.ok_or(Error::<T>::ArithmeticError)?;

		Ok(current_cr as u32)
	}

	/// 금고 상태 결정
	///
	/// 현재 담보율을 기반으로 금고 상태를 결정합니다.
	///
	/// # 매개변수
	/// - `current_cr`: 현재 담보율 (백분율)
	///
	/// # 반환값
	/// - `VaultStatus`: 금고 상태
	pub fn determine_vault_status(current_cr: u32) -> VaultStatus {
		if current_cr >= 150 {
			// ≥ 150%: 정상
			VaultStatus::Active
		} else if current_cr >= 145 {
			// 145%-150%: 1단계 (차익거래 유도)
			VaultStatus::DeRisk
		} else if current_cr >= 140 {
			// 140%-145%: 2단계 (부분 청산)
			VaultStatus::PartialLiquid
		} else {
			// < 140%: 3단계 (강제 청산)
			VaultStatus::EmergencyStop
		}
	}

	/// 모든 금고 모니터링
	///
	/// 블록마다 모든 금고의 상태를 확인하고 필요시 상태를 변경합니다.
	pub fn monitor_all_vaults() {
		for (loan_id, mut vault) in Vaults::<T>::iter() {
			// 현재 담보율 계산
			let current_cr = match Self::calculate_current_collateral_ratio(&vault) {
				Ok(cr) => cr,
				Err(_) => continue, // 오류 발생 시 다음 금고로
			};

			// 새 상태 결정
			let new_status = Self::determine_vault_status(current_cr);

			// 상태가 변경되었으면 업데이트
			if vault.status != new_status {
				let old_status = vault.status.clone();
				vault.status = new_status.clone();
				vault.last_update_block = <frame_system::Pallet<T>>::block_number();
				Vaults::<T>::insert(loan_id, vault);

				// 이벤트 발행
				Self::deposit_event(Event::VaultStatusChanged { loan_id, old_status, new_status });
			}
		}
	}

	/// 팔렛 계정 ID 가져오기
	///
	/// Treasury 주소로 사용됩니다.
	pub fn account_id() -> T::AccountId {
		T::PalletId::get().into_account_truncating()
	}

	/// 사용자의 총 부채 조회
	///
	/// # 매개변수
	/// - `account`: 사용자 계정
	///
	/// # 반환값
	/// - `u128`: 총 부채 금액
	pub fn get_total_debt(account: &T::AccountId) -> u128 {
		let loan_ids = UserLoans::<T>::get(account);
		let mut total_debt = 0u128;

		for loan_id in loan_ids.iter() {
			if let Some(vault) = Vaults::<T>::get(loan_id) {
				total_debt = total_debt.saturating_add(vault.debt_amount);
			}
		}

		total_debt
	}

	/// 사용자의 총 담보 가치 조회
	///
	/// # 매개변수
	/// - `account`: 사용자 계정
	///
	/// # 반환값
	/// - `u128`: 총 담보 가치 (USD)
	pub fn get_total_collateral_value(account: &T::AccountId) -> u128 {
		let loan_ids = UserLoans::<T>::get(account);
		let mut total_collateral_value = 0u128;

		for loan_id in loan_ids.iter() {
			if let Some(vault) = Vaults::<T>::get(loan_id) {
				let asset_price = AssetPrices::<T>::get(vault.collateral_asset_id);
				let collateral_value = vault
					.collateral_amount
					.saturating_mul(asset_price)
					.saturating_div(1_000_000);
				total_collateral_value = total_collateral_value.saturating_add(collateral_value);
			}
		}

		total_collateral_value
	}

	/// 사용자의 평균 담보율 조회
	///
	/// # 매개변수
	/// - `account`: 사용자 계정
	///
	/// # 반환값
	/// - `Option<u32>`: 평균 담보율 (백분율) 또는 None
	pub fn get_average_collateral_ratio(account: &T::AccountId) -> Option<u32> {
		let total_debt = Self::get_total_debt(account);
		if total_debt == 0 {
			return None
		}

		let total_collateral_value = Self::get_total_collateral_value(account);

		// 평균 담보율 = (total_collateral_value / total_debt) × 100
		let avg_cr = total_collateral_value.saturating_mul(100).saturating_div(total_debt);

		Some(avg_cr as u32)
	}

	/// 시스템 총 담보율 조회
	///
	/// # 반환값
	/// - `Option<u32>`: 시스템 총 담보율 (백분율) 또는 None
	pub fn get_system_collateral_ratio() -> Option<u32> {
		let total_supply = TotalSupply::<T>::get();
		if total_supply == 0 {
			return None
		}

		let total_collateral_value = TotalCollateralValue::<T>::get();

		// 시스템 담보율 = (total_collateral_value / total_supply) × 100
		let system_cr = total_collateral_value.saturating_mul(100).saturating_div(total_supply);

		Some(system_cr as u32)
	}

	/// 대출 가능 금액 계산
	///
	/// # 매개변수
	/// - `account`: 사용자 계정
	/// - `asset_id`: 담보 자산 ID
	/// - `collateral_amount`: 담보 수량
	///
	/// # 반환값
	/// - `Result<u128, DispatchError>`: 대출 가능 금액 또는 오류
	pub fn calculate_max_loan_amount(
		account: &T::AccountId,
		asset_id: AssetId,
		collateral_amount: u128,
	) -> Result<u128, DispatchError> {
		// 기여도 점수 조회
		let cs = ContributionScores::<T>::get(account);

		// 동적 담보율 계산
		let cr_dynamic = Self::calculate_dynamic_collateral_ratio(
			cs,
			T::BaseCollateralRatio::get(),
			T::MinCollateralRatio::get(),
		);

		// 담보 가치 계산
		let asset_price = AssetPrices::<T>::get(asset_id);
		ensure!(asset_price > 0, Error::<T>::PriceNotFound);

		let collateral_value = collateral_amount
			.checked_mul(asset_price)
			.ok_or(Error::<T>::ArithmeticError)?
			.checked_div(1_000_000)
			.ok_or(Error::<T>::ArithmeticError)?;

		// 최대 대출 금액 계산
		// V_loan_max = V_collateral × 100 / CR_dynamic
		let max_loan = collateral_value
			.checked_mul(100)
			.ok_or(Error::<T>::ArithmeticError)?
			.checked_div(cr_dynamic as u128)
			.ok_or(Error::<T>::ArithmeticError)?;

		Ok(max_loan)
	}

	/// 금고 건강도 점수 계산
	///
	/// 담보율을 기반으로 금고의 건강도를 0-100 점수로 반환합니다.
	///
	/// # 매개변수
	/// - `loan_id`: 대출 ID
	///
	/// # 반환값
	/// - `Result<u32, DispatchError>`: 건강도 점수 (0-100) 또는 오류
	pub fn calculate_vault_health_score(loan_id: LoanId) -> Result<u32, DispatchError> {
		let vault = Vaults::<T>::get(loan_id).ok_or(Error::<T>::VaultNotFound)?;
		let current_cr = Self::calculate_current_collateral_ratio(&vault)?;

		// 건강도 점수 계산
		// 150% 이상: 100점
		// 140%-150%: 50-100점 (선형)
		// 140% 미만: 0-50점 (선형)
		let health_score = if current_cr >= 150 {
			100
		} else if current_cr >= 140 {
			// (current_cr - 140) / (150 - 140) * 50 + 50
			let ratio = (current_cr - 140) * 50 / 10;
			ratio + 50
		} else {
			// current_cr / 140 * 50
			current_cr * 50 / 140
		};

		Ok(health_score)
	}
}

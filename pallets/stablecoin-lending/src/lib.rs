#![cfg_attr(not(feature = "std"), no_std)]

//! # AFE Protocol - Stablecoin Lending Pallet (The Heart)
//!
//! AFE Protocol의 핵심 대출 엔진으로, 기여도 기반 동적 담보율과
//! 3단계 청산 방지 시스템을 통해 안정적인 스테이블코인 발행을 제공합니다.
//!
//! ## 핵심 기능
//!
//! - **기여도 점수 (CS)**: 사용자의 플랫폼 기여도를 정량화
//! - **동적 담보율 (CR_dynamic)**: CS에 따라 50%-150% 범위로 조정
//! - **3단계 청산 방지**: De-Risk, Partial Liquidation, Emergency Stop
//! - **통합 검증**: Shield (LTV/KYC), Brain (가격 조정) 연동 준비
//!
//! ## 공식
//!
//! - CS = 0.30×LP + 0.25×TV + 0.20×GP + 0.15×HD + 0.10×TS
//! - CR_dynamic = 150% - CS (범위: 50%-150%)
//! - V_loan_max = V_collateral / CR_dynamic

pub use pallet::*;

#[cfg(test)]
mod mock;

#[cfg(test)]
mod tests;

use codec::{Decode, Encode, MaxEncodedLen};
use frame_support::{
    pallet_prelude::*,
    traits::{Currency, ExistenceRequirement, ReservableCurrency},
};
use frame_system::pallet_prelude::*;
use scale_info::TypeInfo;
use sp_arithmetic::{
    traits::{CheckedAdd, CheckedDiv, CheckedMul, CheckedSub, Saturating, Zero},
    FixedU128, Permill,
};
use sp_runtime::{
    traits::{AccountIdConversion, One},
    DispatchError, RuntimeDebug,
};
use sp_std::prelude::*;

/// 대출 ID 타입
pub type LoanId = u64;

/// 자산 ID 타입
pub type AssetId = u32;

/// 기여도 점수 타입 (0-100)
pub type ContributionScore = u32;

#[frame_support::pallet]
pub mod pallet {
    use super::*;

    /// Pallet 설정 트레잇
    #[pallet::config]
    pub trait Config: frame_system::Config {
        /// 런타임 이벤트 타입
        type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;

        /// 통화 타입 (담보 자산)
        type Currency: Currency<Self::AccountId> + ReservableCurrency<Self::AccountId>;

        /// 최대 대출 수
        #[pallet::constant]
        type MaxLoans: Get<u32>;

        /// 최소 담보율 (50% = 5000 basis points)
        #[pallet::constant]
        type MinCollateralRatio: Get<u32>;

        /// 기본 담보율 (150% = 15000 basis points)
        #[pallet::constant]
        type BaseCollateralRatio: Get<u32>;

        /// De-Risk 임계값 (145% = 14500 basis points)
        #[pallet::constant]
        type DeRiskThreshold: Get<u32>;

        /// 부분 청산 임계값 (140% = 14000 basis points)
        #[pallet::constant]
        type PartialLiquidationThreshold: Get<u32>;

        /// 긴급 청산 임계값 (140% 미만)
        #[pallet::constant]
        type EmergencyThreshold: Get<u32>;

        /// 기본 이자율 (연 5% = 500 basis points)
        #[pallet::constant]
        type BaseInterestRate: Get<u32>;

        /// 청산 인센티브 (5% = 500 basis points)
        #[pallet::constant]
        type LiquidationIncentive: Get<u32>;

        // TODO: Brain 연동 시 활성화
        // /// 리스크 매니저 (Brain)
        // type RiskManager: RiskManagerInterface;

        // TODO: Shield 연동 시 활성화
        // /// 신뢰 검증자 (Shield)
        // type TrustVerifier: TrustVerifierInterface;
    }

    #[pallet::pallet]
    pub struct Pallet<T>(_);

    /// 대출 금고 상태
    #[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
    pub enum VaultStatus {
        /// 정상 상태 (CR >= 145%)
        Active,
        /// 1단계: 차익거래 유도 (145% <= CR < 150%)
        DeRisk,
        /// 2단계: 부분 청산 (140% <= CR < 145%)
        PartialLiquid,
        /// 3단계: 강제 청산 (CR < 140%)
        EmergencyStop,
    }

    impl Default for VaultStatus {
        fn default() -> Self {
            VaultStatus::Active
        }
    }

    /// 대출 금고 정보
    #[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
    #[scale_info(skip_type_params(T))]
    pub struct LoanVault<T: Config> {
        /// 차입자
        pub borrower: T::AccountId,
        /// 담보 자산 ID
        pub collateral_asset_id: AssetId,
        /// 담보 금액
        pub collateral_amount: BalanceOf<T>,
        /// 부채 금액 (발행된 스테이블코인)
        pub debt_amount: BalanceOf<T>,
        /// 담보율 (basis points, 10000 = 100%)
        pub collateral_ratio: u32,
        /// 이자율 (basis points per year, 500 = 5%)
        pub interest_rate: u32,
        /// 마지막 업데이트 블록
        pub last_update_block: BlockNumberFor<T>,
        /// 금고 상태
        pub status: VaultStatus,
        /// 누적 이자
        pub accrued_interest: BalanceOf<T>,
    }

    /// 기여도 점수 상세 정보
    #[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
    pub struct ContributionScoreDetails {
        /// LP: 유동성 제공 점수 (0-100)
        pub liquidity_provision: u32,
        /// TV: 총 예치 가치 점수 (0-100)
        pub total_value_locked: u32,
        /// GP: 거버넌스 참여 점수 (0-100)
        pub governance_participation: u32,
        /// HD: 과거 부채 이력 점수 (0-100)
        pub historical_debt: u32,
        /// TS: 재직 기간 점수 (0-100)
        pub tenure_score: u32,
        /// 총 기여도 점수 (0-100)
        pub total_score: u32,
        /// 마지막 업데이트 블록
        pub last_updated: u32,
    }

    impl Default for ContributionScoreDetails {
        fn default() -> Self {
            Self {
                liquidity_provision: 50,
                total_value_locked: 50,
                governance_participation: 50,
                historical_debt: 50,
                tenure_score: 50,
                total_score: 50,
                last_updated: 0,
            }
        }
    }

    /// 청산 이벤트 정보
    #[derive(Clone, Encode, Decode, Eq, PartialEq, RuntimeDebug, TypeInfo, MaxEncodedLen)]
    #[scale_info(skip_type_params(T))]
    pub struct LiquidationEvent<T: Config> {
        /// 청산된 대출 ID
        pub loan_id: LoanId,
        /// 청산자
        pub liquidator: T::AccountId,
        /// 청산된 담보 금액
        pub collateral_liquidated: BalanceOf<T>,
        /// 상환된 부채 금액
        pub debt_repaid: BalanceOf<T>,
        /// 청산 블록 번호
        pub block_number: BlockNumberFor<T>,
    }

    type BalanceOf<T> = <<T as Config>::Currency as Currency<<T as frame_system::Config>::AccountId>>::Balance;

    /// 저장소: 대출 금고
    #[pallet::storage]
    #[pallet::getter(fn vaults)]
    pub type Vaults<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        LoanId,
        LoanVault<T>,
        OptionQuery,
    >;

    /// 저장소: 사용자별 기여도 점수
    #[pallet::storage]
    #[pallet::getter(fn contribution_scores)]
    pub type ContributionScores<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        T::AccountId,
        ContributionScoreDetails,
        ValueQuery,
    >;

    /// 저장소: 사용자별 대출 ID 목록
    #[pallet::storage]
    #[pallet::getter(fn user_loans)]
    pub type UserLoans<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        T::AccountId,
        BoundedVec<LoanId, T::MaxLoans>,
        ValueQuery,
    >;

    /// 저장소: 총 대출 수
    #[pallet::storage]
    #[pallet::getter(fn loan_count)]
    pub type LoanCount<T: Config> = StorageValue<_, LoanId, ValueQuery>;

    /// 저장소: 총 발행된 스테이블코인
    #[pallet::storage]
    #[pallet::getter(fn total_supply)]
    pub type TotalSupply<T: Config> = StorageValue<_, BalanceOf<T>, ValueQuery>;

    /// 저장소: 총 담보 가치
    #[pallet::storage]
    #[pallet::getter(fn total_collateral_value)]
    pub type TotalCollateralValue<T: Config> = StorageValue<_, BalanceOf<T>, ValueQuery>;

    /// 저장소: 청산 이벤트 히스토리
    #[pallet::storage]
    #[pallet::getter(fn liquidation_history)]
    pub type LiquidationHistory<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        LoanId,
        BoundedVec<LiquidationEvent<T>, ConstU32<100>>,
        ValueQuery,
    >;

    /// 저장소: 자산 가격 (모의용, Brain 연동 전)
    #[pallet::storage]
    #[pallet::getter(fn asset_prices)]
    pub type AssetPrices<T: Config> = StorageMap<
        _,
        Blake2_128Concat,
        AssetId,
        BalanceOf<T>,
        ValueQuery,
    >;

    /// Genesis 설정
    #[pallet::genesis_config]
    #[derive(frame_support::DefaultNoBound)]
    pub struct GenesisConfig<T: Config> {
        #[serde(skip)]
        pub _phantom: sp_std::marker::PhantomData<T>,
    }

    #[pallet::genesis_build]
    impl<T: Config> BuildGenesisConfig for GenesisConfig<T> {
        fn build(&self) {
            // Genesis 초기화 로직
            LoanCount::<T>::put(0u64);
            TotalSupply::<T>::put(BalanceOf::<T>::zero());
            TotalCollateralValue::<T>::put(BalanceOf::<T>::zero());
        }
    }

    /// 이벤트
    #[pallet::event]
    #[pallet::generate_deposit(pub(super) fn deposit_event)]
    pub enum Event<T: Config> {
        /// 대출 발행됨
        LoanIssued {
            loan_id: LoanId,
            borrower: T::AccountId,
            collateral_amount: BalanceOf<T>,
            loan_amount: BalanceOf<T>,
            collateral_ratio: u32,
        },
        /// 대출 상환됨
        LoanRepaid {
            loan_id: LoanId,
            borrower: T::AccountId,
            amount: BalanceOf<T>,
            remaining_debt: BalanceOf<T>,
        },
        /// 담보 추가됨
        CollateralAdded {
            loan_id: LoanId,
            borrower: T::AccountId,
            amount: BalanceOf<T>,
            new_total: BalanceOf<T>,
        },
        /// 금고 상태 변경됨
        VaultStatusChanged {
            loan_id: LoanId,
            old_status: VaultStatus,
            new_status: VaultStatus,
            current_ratio: u32,
        },
        /// 부분 청산 실행됨
        PartialLiquidation {
            loan_id: LoanId,
            liquidator: T::AccountId,
            collateral_liquidated: BalanceOf<T>,
            debt_repaid: BalanceOf<T>,
        },
        /// 긴급 청산 실행됨
        EmergencyLiquidation {
            loan_id: LoanId,
            liquidator: T::AccountId,
            collateral_liquidated: BalanceOf<T>,
            debt_repaid: BalanceOf<T>,
        },
        /// 기여도 점수 업데이트됨
        ContributionScoreUpdated {
            account: T::AccountId,
            old_score: u32,
            new_score: u32,
        },
        /// 이자 발생됨
        InterestAccrued {
            loan_id: LoanId,
            amount: BalanceOf<T>,
            new_total_debt: BalanceOf<T>,
        },
        /// 자산 가격 업데이트됨 (모의용)
        AssetPriceUpdated {
            asset_id: AssetId,
            price: BalanceOf<T>,
        },
    }

    /// 에러
    #[pallet::error]
    pub enum Error<T> {
        /// 담보 부족
        InsufficientCollateral,
        /// 금고를 찾을 수 없음
        VaultNotFound,
        /// 잘못된 대출 금액
        InvalidLoanAmount,
        /// 산술 연산 오류
        ArithmeticError,
        /// 시스템 리스크가 너무 높음
        SystemRiskTooHigh,
        /// 권한 없음
        Unauthorized,
        /// 금고가 이미 청산됨
        VaultAlreadyLiquidated,
        /// 청산 조건 미충족
        LiquidationConditionNotMet,
        /// 최대 대출 수 초과
        MaxLoansExceeded,
        /// 잘못된 담보율
        InvalidCollateralRatio,
        /// 대출이 활성 상태가 아님
        VaultNotActive,
        /// 상환 금액이 너무 큼
        RepaymentTooLarge,
        /// 잔액 부족
        InsufficientBalance,
        /// LTV 증명이 없음 (Shield 연동 시)
        LtvProofNotFound,
        /// KYC 검증 실패 (Shield 연동 시)
        KycVerificationFailed,
        /// 가격 조회 실패 (Brain 연동 시)
        PriceOracleError,
        /// 기여도 점수가 유효하지 않음
        InvalidContributionScore,
    }

    #[pallet::hooks]
    impl<T: Config> Hooks<BlockNumberFor<T>> for Pallet<T> {
        /// 블록 초기화 시 모든 금고 모니터링
        fn on_initialize(n: BlockNumberFor<T>) -> Weight {
            // 모든 활성 금고 모니터링
            let _ = Self::monitor_all_vaults();

            // 가중치 반환 (실제로는 처리된 금고 수에 비례해야 함)
            Weight::from_parts(10_000_000, 0)
        }
    }

    #[pallet::call]
    impl<T: Config> Pallet<T> {
        /// 대출 실행
        ///
        /// # 매개변수
        /// - `origin`: 차입자
        /// - `asset_id`: 담보 자산 ID
        /// - `collateral_amount`: 담보 금액
        /// - `loan_amount`: 대출 금액 (발행할 스테이블코인)
        #[pallet::call_index(0)]
        #[pallet::weight(10_000)]
        pub fn execute_loan(
            origin: OriginFor<T>,
            asset_id: AssetId,
            collateral_amount: BalanceOf<T>,
            loan_amount: BalanceOf<T>,
        ) -> DispatchResult {
            let borrower = ensure_signed(origin)?;

            // 1. 입력 검증
            ensure!(
                !collateral_amount.is_zero() && !loan_amount.is_zero(),
                Error::<T>::InvalidLoanAmount
            );

            // TODO: Shield 연동 시 활성화
            // 2. LTV/KYC 검증
            // ensure!(
            //     T::TrustVerifier::has_valid_ltv_proof(&borrower),
            //     Error::<T>::LtvProofNotFound
            // );
            // ensure!(
            //     T::TrustVerifier::verify_kyc(&borrower),
            //     Error::<T>::KycVerificationFailed
            // );

            // TODO: Brain 연동 시 활성화
            // 3. 조정된 가격 조회 (P_adj)
            // let adjusted_price = T::RiskManager::get_adjusted_price(asset_id)
            //     .ok_or(Error::<T>::PriceOracleError)?;

            // 모의 가격 사용 (현재)
            let asset_price = Self::get_asset_price(asset_id);

            // 4. 기여도 점수 (CS) 계산
            let cs_details = Self::get_or_create_contribution_score(&borrower);
            let contribution_score = cs_details.total_score;

            // 5. 동적 담보율 (CR_dynamic) 계산
            let dynamic_cr = Self::calculate_dynamic_collateral_ratio(contribution_score)?;

            // 6. 담보 가치 계산
            let collateral_value = Self::calculate_collateral_value(
                collateral_amount,
                asset_price,
            )?;

            // 7. 최대 대출 가능 금액 확인
            let max_loan_amount = Self::calculate_max_loan_amount(
                collateral_value,
                dynamic_cr,
            )?;

            ensure!(
                loan_amount <= max_loan_amount,
                Error::<T>::InsufficientCollateral
            );

            // 8. 담보 예치 (Reserve)
            T::Currency::reserve(&borrower, collateral_amount)?;

            // 9. 대출 ID 생성
            let loan_id = Self::loan_count();
            let next_loan_id = loan_id
                .checked_add(1)
                .ok_or(Error::<T>::ArithmeticError)?;

            // 10. LoanVault 생성
            let vault = LoanVault {
                borrower: borrower.clone(),
                collateral_asset_id: asset_id,
                collateral_amount,
                debt_amount: loan_amount,
                collateral_ratio: dynamic_cr,
                interest_rate: T::BaseInterestRate::get(),
                last_update_block: frame_system::Pallet::<T>::block_number(),
                status: VaultStatus::Active,
                accrued_interest: BalanceOf::<T>::zero(),
            };

            // 11. 저장소 업데이트
            Vaults::<T>::insert(loan_id, vault);
            LoanCount::<T>::put(next_loan_id);

            // 12. 사용자 대출 목록에 추가
            UserLoans::<T>::try_mutate(&borrower, |loans| {
                loans.try_push(loan_id)
                    .map_err(|_| Error::<T>::MaxLoansExceeded)
            })?;

            // 13. 총 공급 및 담보 가치 업데이트
            TotalSupply::<T>::mutate(|total| {
                *total = total.saturating_add(loan_amount);
            });
            TotalCollateralValue::<T>::mutate(|total| {
                *total = total.saturating_add(collateral_value);
            });

            // TODO: 실제로는 스테이블코인 발행 로직 구현
            // 14. 스테이블코인 발행 (모의)
            // T::Currency::deposit_creating(&borrower, loan_amount);

            // 15. 이벤트 발행
            Self::deposit_event(Event::LoanIssued {
                loan_id,
                borrower,
                collateral_amount,
                loan_amount,
                collateral_ratio: dynamic_cr,
            });

            Ok(())
        }

        /// 대출 상환
        ///
        /// # 매개변수
        /// - `origin`: 상환자
        /// - `loan_id`: 대출 ID
        /// - `repay_amount`: 상환 금액
        #[pallet::call_index(1)]
        #[pallet::weight(10_000)]
        pub fn repay_loan(
            origin: OriginFor<T>,
            loan_id: LoanId,
            repay_amount: BalanceOf<T>,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            ensure!(!repay_amount.is_zero(), Error::<T>::InvalidLoanAmount);

            // 1. 금고 조회
            let mut vault = Vaults::<T>::get(loan_id)
                .ok_or(Error::<T>::VaultNotFound)?;

            // 2. 권한 확인
            ensure!(vault.borrower == who, Error::<T>::Unauthorized);

            // 3. 이자 업데이트
            Self::accrue_interest(loan_id, &mut vault)?;

            // 4. 총 부채 계산 (원금 + 이자)
            let total_debt = vault.debt_amount
                .checked_add(&vault.accrued_interest)
                .ok_or(Error::<T>::ArithmeticError)?;

            // 5. 상환 금액 확인
            ensure!(repay_amount <= total_debt, Error::<T>::RepaymentTooLarge);

            // TODO: 실제로는 스테이블코인 소각 로직 구현
            // 6. 스테이블코인 소각 (모의)
            // T::Currency::withdraw(
            //     &who,
            //     repay_amount,
            //     WithdrawReasons::all(),
            //     ExistenceRequirement::KeepAlive,
            // )?;

            // 7. 부채 감소
            let remaining_debt = total_debt
                .checked_sub(&repay_amount)
                .ok_or(Error::<T>::ArithmeticError)?;

            // 8. 이자와 원금 분리 처리
            if repay_amount >= vault.accrued_interest {
                let principal_payment = repay_amount
                    .checked_sub(&vault.accrued_interest)
                    .ok_or(Error::<T>::ArithmeticError)?;

                vault.accrued_interest = BalanceOf::<T>::zero();
                vault.debt_amount = vault.debt_amount
                    .checked_sub(&principal_payment)
                    .ok_or(Error::<T>::ArithmeticError)?;
            } else {
                vault.accrued_interest = vault.accrued_interest
                    .checked_sub(&repay_amount)
                    .ok_or(Error::<T>::ArithmeticError)?;
            }

            // 9. 전액 상환 시 담보 반환
            if remaining_debt.is_zero() {
                T::Currency::unreserve(&vault.borrower, vault.collateral_amount);

                // 금고 삭제
                Vaults::<T>::remove(loan_id);

                // 사용자 대출 목록에서 제거
                UserLoans::<T>::mutate(&who, |loans| {
                    loans.retain(|&id| id != loan_id);
                });

                // 총 공급 및 담보 가치 업데이트
                let asset_price = Self::get_asset_price(vault.collateral_asset_id);
                let collateral_value = Self::calculate_collateral_value(
                    vault.collateral_amount,
                    asset_price,
                )?;

                TotalSupply::<T>::mutate(|total| {
                    *total = total.saturating_sub(vault.debt_amount);
                });
                TotalCollateralValue::<T>::mutate(|total| {
                    *total = total.saturating_sub(collateral_value);
                });
            } else {
                // 10. 담보율 재계산 및 금고 업데이트
                let asset_price = Self::get_asset_price(vault.collateral_asset_id);
                let current_ratio = Self::calculate_current_collateral_ratio(
                    vault.collateral_amount,
                    asset_price,
                    remaining_debt,
                )?;

                vault.collateral_ratio = current_ratio;
                vault.last_update_block = frame_system::Pallet::<T>::block_number();

                // 11. 상태 업데이트
                let new_status = Self::determine_vault_status(current_ratio);
                let old_status = vault.status.clone();
                vault.status = new_status.clone();

                Vaults::<T>::insert(loan_id, vault.clone());

                if old_status != new_status {
                    Self::deposit_event(Event::VaultStatusChanged {
                        loan_id,
                        old_status,
                        new_status,
                        current_ratio,
                    });
                }

                TotalSupply::<T>::mutate(|total| {
                    *total = total.saturating_sub(repay_amount);
                });
            }

            // 12. 이벤트 발행
            Self::deposit_event(Event::LoanRepaid {
                loan_id,
                borrower: who,
                amount: repay_amount,
                remaining_debt,
            });

            Ok(())
        }

        /// 담보 추가
        ///
        /// # 매개변수
        /// - `origin`: 담보 추가자
        /// - `loan_id`: 대출 ID
        /// - `additional_collateral`: 추가 담보 금액
        #[pallet::call_index(2)]
        #[pallet::weight(10_000)]
        pub fn add_collateral(
            origin: OriginFor<T>,
            loan_id: LoanId,
            additional_collateral: BalanceOf<T>,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            ensure!(
                !additional_collateral.is_zero(),
                Error::<T>::InvalidLoanAmount
            );

            // 1. 금고 조회
            let mut vault = Vaults::<T>::get(loan_id)
                .ok_or(Error::<T>::VaultNotFound)?;

            // 2. 권한 확인
            ensure!(vault.borrower == who, Error::<T>::Unauthorized);

            // 3. 추가 담보 예치
            T::Currency::reserve(&who, additional_collateral)?;

            // 4. 담보 금액 업데이트
            let new_collateral_amount = vault.collateral_amount
                .checked_add(&additional_collateral)
                .ok_or(Error::<T>::ArithmeticError)?;

            vault.collateral_amount = new_collateral_amount;

            // 5. 이자 업데이트
            Self::accrue_interest(loan_id, &mut vault)?;

            // 6. 담보율 재계산
            let asset_price = Self::get_asset_price(vault.collateral_asset_id);
            let total_debt = vault.debt_amount
                .checked_add(&vault.accrued_interest)
                .ok_or(Error::<T>::ArithmeticError)?;

            let current_ratio = Self::calculate_current_collateral_ratio(
                new_collateral_amount,
                asset_price,
                total_debt,
            )?;

            vault.collateral_ratio = current_ratio;
            vault.last_update_block = frame_system::Pallet::<T>::block_number();

            // 7. 상태 업데이트
            let old_status = vault.status.clone();
            let new_status = Self::determine_vault_status(current_ratio);
            vault.status = new_status.clone();

            Vaults::<T>::insert(loan_id, vault);

            // 8. 총 담보 가치 업데이트
            let additional_value = Self::calculate_collateral_value(
                additional_collateral,
                asset_price,
            )?;

            TotalCollateralValue::<T>::mutate(|total| {
                *total = total.saturating_add(additional_value);
            });

            // 9. 이벤트 발행
            Self::deposit_event(Event::CollateralAdded {
                loan_id,
                borrower: who,
                amount: additional_collateral,
                new_total: new_collateral_amount,
            });

            if old_status != new_status {
                Self::deposit_event(Event::VaultStatusChanged {
                    loan_id,
                    old_status,
                    new_status,
                    current_ratio,
                });
            }

            Ok(())
        }

        /// 부분 청산 실행
        ///
        /// # 매개변수
        /// - `origin`: 청산자
        /// - `loan_id`: 대출 ID
        /// - `repay_amount`: 상환할 부채 금액
        #[pallet::call_index(3)]
        #[pallet::weight(10_000)]
        pub fn partial_liquidate(
            origin: OriginFor<T>,
            loan_id: LoanId,
            repay_amount: BalanceOf<T>,
        ) -> DispatchResult {
            let liquidator = ensure_signed(origin)?;

            ensure!(!repay_amount.is_zero(), Error::<T>::InvalidLoanAmount);

            // 1. 금고 조회
            let mut vault = Vaults::<T>::get(loan_id)
                .ok_or(Error::<T>::VaultNotFound)?;

            // 2. 부분 청산 조건 확인 (PartialLiquid 상태)
            ensure!(
                vault.status == VaultStatus::PartialLiquid,
                Error::<T>::LiquidationConditionNotMet
            );

            // 3. 이자 업데이트
            Self::accrue_interest(loan_id, &mut vault)?;

            // 4. 총 부채 계산
            let total_debt = vault.debt_amount
                .checked_add(&vault.accrued_interest)
                .ok_or(Error::<T>::ArithmeticError)?;

            ensure!(repay_amount <= total_debt, Error::<T>::RepaymentTooLarge);

            // 5. 청산할 담보 계산 (청산 인센티브 포함)
            let asset_price = Self::get_asset_price(vault.collateral_asset_id);
            let liquidation_incentive = T::LiquidationIncentive::get();

            // collateral_to_liquidate = repay_amount / price * (1 + incentive)
            let collateral_to_liquidate = Self::calculate_liquidation_collateral(
                repay_amount,
                asset_price,
                liquidation_incentive,
            )?;

            ensure!(
                collateral_to_liquidate <= vault.collateral_amount,
                Error::<T>::InsufficientCollateral
            );

            // TODO: 실제로는 스테이블코인 소각 로직 구현
            // 6. 청산자로부터 스테이블코인 받기 (모의)
            // T::Currency::withdraw(
            //     &liquidator,
            //     repay_amount,
            //     WithdrawReasons::all(),
            //     ExistenceRequirement::KeepAlive,
            // )?;

            // 7. 담보 이전
            T::Currency::repatriate_reserved(
                &vault.borrower,
                &liquidator,
                collateral_to_liquidate,
                frame_support::traits::BalanceStatus::Free,
            )?;

            // 8. 금고 업데이트
            vault.collateral_amount = vault.collateral_amount
                .checked_sub(&collateral_to_liquidate)
                .ok_or(Error::<T>::ArithmeticError)?;

            // 이자 우선 상환
            if repay_amount >= vault.accrued_interest {
                let principal_payment = repay_amount
                    .checked_sub(&vault.accrued_interest)
                    .ok_or(Error::<T>::ArithmeticError)?;

                vault.accrued_interest = BalanceOf::<T>::zero();
                vault.debt_amount = vault.debt_amount
                    .checked_sub(&principal_payment)
                    .ok_or(Error::<T>::ArithmeticError)?;
            } else {
                vault.accrued_interest = vault.accrued_interest
                    .checked_sub(&repay_amount)
                    .ok_or(Error::<T>::ArithmeticError)?;
            }

            // 9. 담보율 재계산
            let remaining_debt = vault.debt_amount
                .checked_add(&vault.accrued_interest)
                .ok_or(Error::<T>::ArithmeticError)?;

            let current_ratio = Self::calculate_current_collateral_ratio(
                vault.collateral_amount,
                asset_price,
                remaining_debt,
            )?;

            vault.collateral_ratio = current_ratio;
            vault.last_update_block = frame_system::Pallet::<T>::block_number();

            // 10. 상태 업데이트
            let old_status = vault.status.clone();
            let new_status = Self::determine_vault_status(current_ratio);
            vault.status = new_status.clone();

            Vaults::<T>::insert(loan_id, vault.clone());

            // 11. 청산 이벤트 기록
            let liquidation_event = LiquidationEvent {
                loan_id,
                liquidator: liquidator.clone(),
                collateral_liquidated: collateral_to_liquidate,
                debt_repaid: repay_amount,
                block_number: frame_system::Pallet::<T>::block_number(),
            };

            LiquidationHistory::<T>::try_mutate(loan_id, |history| {
                history.try_push(liquidation_event)
                    .map_err(|_| Error::<T>::ArithmeticError)
            })?;

            // 12. 총 공급 및 담보 가치 업데이트
            TotalSupply::<T>::mutate(|total| {
                *total = total.saturating_sub(repay_amount);
            });

            let liquidated_value = Self::calculate_collateral_value(
                collateral_to_liquidate,
                asset_price,
            )?;

            TotalCollateralValue::<T>::mutate(|total| {
                *total = total.saturating_sub(liquidated_value);
            });

            // 13. 이벤트 발행
            Self::deposit_event(Event::PartialLiquidation {
                loan_id,
                liquidator,
                collateral_liquidated: collateral_to_liquidate,
                debt_repaid: repay_amount,
            });

            if old_status != new_status {
                Self::deposit_event(Event::VaultStatusChanged {
                    loan_id,
                    old_status,
                    new_status,
                    current_ratio,
                });
            }

            Ok(())
        }

        /// 긴급 청산 실행
        ///
        /// # 매개변수
        /// - `origin`: 청산자
        /// - `loan_id`: 대출 ID
        #[pallet::call_index(4)]
        #[pallet::weight(10_000)]
        pub fn emergency_liquidate(
            origin: OriginFor<T>,
            loan_id: LoanId,
        ) -> DispatchResult {
            let liquidator = ensure_signed(origin)?;

            // 1. 금고 조회
            let mut vault = Vaults::<T>::get(loan_id)
                .ok_or(Error::<T>::VaultNotFound)?;

            // 2. 긴급 청산 조건 확인 (EmergencyStop 상태)
            ensure!(
                vault.status == VaultStatus::EmergencyStop,
                Error::<T>::LiquidationConditionNotMet
            );

            // 3. 이자 업데이트
            Self::accrue_interest(loan_id, &mut vault)?;

            // 4. 총 부채 계산
            let total_debt = vault.debt_amount
                .checked_add(&vault.accrued_interest)
                .ok_or(Error::<T>::ArithmeticError)?;

            // 5. 전체 담보 청산
            let collateral_to_liquidate = vault.collateral_amount;

            // TODO: 실제로는 스테이블코인 소각 로직 구현
            // 6. 청산자로부터 스테이블코인 받기 (모의)
            // 청산자는 부채만큼의 스테이블코인을 제공하고 담보를 받음
            // T::Currency::withdraw(
            //     &liquidator,
            //     total_debt,
            //     WithdrawReasons::all(),
            //     ExistenceRequirement::KeepAlive,
            // )?;

            // 7. 전체 담보 이전
            T::Currency::repatriate_reserved(
                &vault.borrower,
                &liquidator,
                collateral_to_liquidate,
                frame_support::traits::BalanceStatus::Free,
            )?;

            // 8. 금고 삭제
            Vaults::<T>::remove(loan_id);

            // 9. 사용자 대출 목록에서 제거
            UserLoans::<T>::mutate(&vault.borrower, |loans| {
                loans.retain(|&id| id != loan_id);
            });

            // 10. 청산 이벤트 기록
            let liquidation_event = LiquidationEvent {
                loan_id,
                liquidator: liquidator.clone(),
                collateral_liquidated: collateral_to_liquidate,
                debt_repaid: total_debt,
                block_number: frame_system::Pallet::<T>::block_number(),
            };

            LiquidationHistory::<T>::try_mutate(loan_id, |history| {
                history.try_push(liquidation_event)
                    .map_err(|_| Error::<T>::ArithmeticError)
            })?;

            // 11. 총 공급 및 담보 가치 업데이트
            TotalSupply::<T>::mutate(|total| {
                *total = total.saturating_sub(total_debt);
            });

            let asset_price = Self::get_asset_price(vault.collateral_asset_id);
            let liquidated_value = Self::calculate_collateral_value(
                collateral_to_liquidate,
                asset_price,
            )?;

            TotalCollateralValue::<T>::mutate(|total| {
                *total = total.saturating_sub(liquidated_value);
            });

            // 12. 이벤트 발행
            Self::deposit_event(Event::EmergencyLiquidation {
                loan_id,
                liquidator,
                collateral_liquidated: collateral_to_liquidate,
                debt_repaid: total_debt,
            });

            Ok(())
        }

        /// 기여도 점수 업데이트
        ///
        /// # 매개변수
        /// - `origin`: Root (관리자만 호출 가능)
        /// - `account`: 대상 계정
        /// - `lp`: 유동성 제공 점수 (0-100)
        /// - `tv`: 총 예치 가치 점수 (0-100)
        /// - `gp`: 거버넌스 참여 점수 (0-100)
        /// - `hd`: 과거 부채 이력 점수 (0-100)
        /// - `ts`: 재직 기간 점수 (0-100)
        #[pallet::call_index(5)]
        #[pallet::weight(10_000)]
        pub fn update_contribution_score(
            origin: OriginFor<T>,
            account: T::AccountId,
            lp: u32,
            tv: u32,
            gp: u32,
            hd: u32,
            ts: u32,
        ) -> DispatchResult {
            ensure_root(origin)?;

            // 1. 점수 유효성 검증 (0-100 범위)
            ensure!(
                lp <= 100 && tv <= 100 && gp <= 100 && hd <= 100 && ts <= 100,
                Error::<T>::InvalidContributionScore
            );

            // 2. 기존 점수 조회
            let old_details = ContributionScores::<T>::get(&account);
            let old_score = old_details.total_score;

            // 3. 새 점수 계산
            let total_score = Self::calculate_contribution_score(lp, tv, gp, hd, ts)?;

            // 4. 상세 정보 업데이트
            let new_details = ContributionScoreDetails {
                liquidity_provision: lp,
                total_value_locked: tv,
                governance_participation: gp,
                historical_debt: hd,
                tenure_score: ts,
                total_score,
                last_updated: frame_system::Pallet::<T>::block_number()
                    .saturated_into::<u32>(),
            };

            ContributionScores::<T>::insert(&account, new_details);

            // 5. 이벤트 발행
            Self::deposit_event(Event::ContributionScoreUpdated {
                account,
                old_score,
                new_score: total_score,
            });

            Ok(())
        }

        /// 자산 가격 업데이트 (모의용, Brain 연동 전)
        ///
        /// # 매개변수
        /// - `origin`: Root (관리자만 호출 가능)
        /// - `asset_id`: 자산 ID
        /// - `price`: 가격
        #[pallet::call_index(6)]
        #[pallet::weight(10_000)]
        pub fn update_asset_price(
            origin: OriginFor<T>,
            asset_id: AssetId,
            price: BalanceOf<T>,
        ) -> DispatchResult {
            ensure_root(origin)?;

            ensure!(!price.is_zero(), Error::<T>::InvalidLoanAmount);

            AssetPrices::<T>::insert(asset_id, price);

            Self::deposit_event(Event::AssetPriceUpdated {
                asset_id,
                price,
            });

            Ok(())
        }
    }

    // 내부 헬퍼 함수
    impl<T: Config> Pallet<T> {
        /// 기여도 점수 (CS) 계산
        ///
        /// CS = 0.30×LP + 0.25×TV + 0.20×GP + 0.15×HD + 0.10×TS
        ///
        /// # 매개변수
        /// - `lp`: 유동성 제공 점수 (0-100)
        /// - `tv`: 총 예치 가치 점수 (0-100)
        /// - `gp`: 거버넌스 참여 점수 (0-100)
        /// - `hd`: 과거 부채 이력 점수 (0-100)
        /// - `ts`: 재직 기간 점수 (0-100)
        ///
        /// # 반환값
        /// 총 기여도 점수 (0-100)
        pub fn calculate_contribution_score(
            lp: u32,
            tv: u32,
            gp: u32,
            hd: u32,
            ts: u32,
        ) -> Result<u32, DispatchError> {
            // CS = 0.30×LP + 0.25×TV + 0.20×GP + 0.15×HD + 0.10×TS
            // 가중치를 1000 단위로 계산 (0.30 = 300)
            let weighted_lp = lp.checked_mul(300).ok_or(Error::<T>::ArithmeticError)?;
            let weighted_tv = tv.checked_mul(250).ok_or(Error::<T>::ArithmeticError)?;
            let weighted_gp = gp.checked_mul(200).ok_or(Error::<T>::ArithmeticError)?;
            let weighted_hd = hd.checked_mul(150).ok_or(Error::<T>::ArithmeticError)?;
            let weighted_ts = ts.checked_mul(100).ok_or(Error::<T>::ArithmeticError)?;

            let total = weighted_lp
                .checked_add(weighted_tv)
                .and_then(|x| x.checked_add(weighted_gp))
                .and_then(|x| x.checked_add(weighted_hd))
                .and_then(|x| x.checked_add(weighted_ts))
                .ok_or(Error::<T>::ArithmeticError)?;

            // 1000으로 나누어 원래 스케일로 복원
            let cs = total / 1000;

            // 0-100 범위로 제한
            Ok(cs.min(100))
        }

        /// 동적 담보율 (CR_dynamic) 계산
        ///
        /// CR_dynamic = 150% - CS (범위: 50%-150%)
        ///
        /// # 매개변수
        /// - `contribution_score`: 기여도 점수 (0-100)
        ///
        /// # 반환값
        /// 동적 담보율 (basis points, 10000 = 100%)
        pub fn calculate_dynamic_collateral_ratio(
            contribution_score: u32,
        ) -> Result<u32, DispatchError> {
            // 기본 담보율 150% = 15000 basis points
            let base_ratio = T::BaseCollateralRatio::get();

            // CS를 basis points로 변환 (CS 1점 = 100 basis points = 1%)
            let cs_reduction = contribution_score
                .checked_mul(100)
                .ok_or(Error::<T>::ArithmeticError)?;

            // CR_dynamic = 150% - CS
            let dynamic_ratio = base_ratio
                .checked_sub(cs_reduction)
                .ok_or(Error::<T>::ArithmeticError)?;

            // 최소 담보율 50% = 5000 basis points
            let min_ratio = T::MinCollateralRatio::get();

            // 50%-150% 범위로 제한
            let final_ratio = dynamic_ratio.max(min_ratio).min(base_ratio);

            Ok(final_ratio)
        }

        /// 담보 가치 계산
        ///
        /// # 매개변수
        /// - `collateral_amount`: 담보 수량
        /// - `asset_price`: 자산 가격
        ///
        /// # 반환값
        /// 담보 가치
        fn calculate_collateral_value(
            collateral_amount: BalanceOf<T>,
            asset_price: BalanceOf<T>,
        ) -> Result<BalanceOf<T>, DispatchError> {
            collateral_amount
                .checked_mul(&asset_price)
                .ok_or(Error::<T>::ArithmeticError.into())
        }

        /// 최대 대출 가능 금액 계산
        ///
        /// V_loan_max = V_collateral / CR_dynamic
        ///
        /// # 매개변수
        /// - `collateral_value`: 담보 가치
        /// - `collateral_ratio`: 담보율 (basis points)
        ///
        /// # 반환값
        /// 최대 대출 가능 금액
        fn calculate_max_loan_amount(
            collateral_value: BalanceOf<T>,
            collateral_ratio: u32,
        ) -> Result<BalanceOf<T>, DispatchError> {
            // collateral_ratio는 basis points (10000 = 100%)
            // max_loan = collateral_value * 10000 / collateral_ratio

            let basis_points = 10000u32;

            // Balance 타입으로 변환
            let collateral_value_u128: u128 = collateral_value.saturated_into();
            let ratio_u128: u128 = collateral_ratio.into();

            let max_loan_u128 = collateral_value_u128
                .checked_mul(basis_points.into())
                .and_then(|x| x.checked_div(ratio_u128))
                .ok_or(Error::<T>::ArithmeticError)?;

            // Balance 타입으로 변환
            let max_loan = max_loan_u128.saturated_into();

            Ok(max_loan)
        }

        /// 현재 담보율 계산
        ///
        /// CR_current = (V_collateral / V_debt) * 100%
        ///
        /// # 매개변수
        /// - `collateral_amount`: 담보 수량
        /// - `asset_price`: 자산 가격
        /// - `debt_amount`: 부채 금액
        ///
        /// # 반환값
        /// 현재 담보율 (basis points)
        fn calculate_current_collateral_ratio(
            collateral_amount: BalanceOf<T>,
            asset_price: BalanceOf<T>,
            debt_amount: BalanceOf<T>,
        ) -> Result<u32, DispatchError> {
            if debt_amount.is_zero() {
                return Ok(T::BaseCollateralRatio::get());
            }

            let collateral_value = Self::calculate_collateral_value(
                collateral_amount,
                asset_price,
            )?;

            // CR = (collateral_value / debt_amount) * 10000
            let collateral_value_u128: u128 = collateral_value.saturated_into();
            let debt_amount_u128: u128 = debt_amount.saturated_into();

            let ratio_u128 = collateral_value_u128
                .checked_mul(10000u128)
                .and_then(|x| x.checked_div(debt_amount_u128))
                .ok_or(Error::<T>::ArithmeticError)?;

            let ratio_u32: u32 = ratio_u128.try_into()
                .map_err(|_| Error::<T>::ArithmeticError)?;

            Ok(ratio_u32)
        }

        /// 금고 상태 결정
        ///
        /// # 매개변수
        /// - `current_ratio`: 현재 담보율 (basis points)
        ///
        /// # 반환값
        /// 금고 상태
        fn determine_vault_status(current_ratio: u32) -> VaultStatus {
            let derisk_threshold = T::DeRiskThreshold::get();
            let partial_threshold = T::PartialLiquidationThreshold::get();
            let emergency_threshold = T::EmergencyThreshold::get();

            if current_ratio < emergency_threshold {
                VaultStatus::EmergencyStop
            } else if current_ratio < partial_threshold {
                VaultStatus::PartialLiquid
            } else if current_ratio < derisk_threshold {
                VaultStatus::DeRisk
            } else {
                VaultStatus::Active
            }
        }

        /// 모든 금고 모니터링 (on_initialize에서 호출)
        fn monitor_all_vaults() -> DispatchResult {
            for (loan_id, mut vault) in Vaults::<T>::iter() {
                // 이자 발생
                let _ = Self::accrue_interest(loan_id, &mut vault);

                // 현재 담보율 계산
                let asset_price = Self::get_asset_price(vault.collateral_asset_id);
                let total_debt = vault.debt_amount
                    .checked_add(&vault.accrued_interest)
                    .unwrap_or(vault.debt_amount);

                let current_ratio = Self::calculate_current_collateral_ratio(
                    vault.collateral_amount,
                    asset_price,
                    total_debt,
                ).unwrap_or(T::BaseCollateralRatio::get());

                // 상태 업데이트
                let old_status = vault.status.clone();
                let new_status = Self::determine_vault_status(current_ratio);

                if old_status != new_status {
                    vault.status = new_status.clone();
                    vault.collateral_ratio = current_ratio;
                    Vaults::<T>::insert(loan_id, vault);

                    Self::deposit_event(Event::VaultStatusChanged {
                        loan_id,
                        old_status,
                        new_status,
                        current_ratio,
                    });
                }
            }

            Ok(())
        }

        /// 이자 발생
        ///
        /// # 매개변수
        /// - `loan_id`: 대출 ID
        /// - `vault`: 금고 (mutable reference)
        fn accrue_interest(
            loan_id: LoanId,
            vault: &mut LoanVault<T>,
        ) -> DispatchResult {
            let current_block = frame_system::Pallet::<T>::block_number();
            let blocks_elapsed = current_block.saturating_sub(vault.last_update_block);

            if blocks_elapsed.is_zero() {
                return Ok(());
            }

            // 연 이자율을 블록당 이자율로 변환
            // 가정: 1년 = 5,256,000 블록 (6초/블록)
            let blocks_per_year = 5_256_000u32;
            let interest_rate = vault.interest_rate;

            // interest = principal * rate * time
            // rate = interest_rate / 10000 (basis points)
            // time = blocks_elapsed / blocks_per_year

            let principal_u128: u128 = vault.debt_amount.saturated_into();
            let blocks_elapsed_u32: u32 = blocks_elapsed.saturated_into();

            let interest_u128 = principal_u128
                .checked_mul(interest_rate.into())
                .and_then(|x| x.checked_mul(blocks_elapsed_u32.into()))
                .and_then(|x| x.checked_div(10000u128))
                .and_then(|x| x.checked_div(blocks_per_year.into()))
                .ok_or(Error::<T>::ArithmeticError)?;

            let interest: BalanceOf<T> = interest_u128.saturated_into();

            // 누적 이자 업데이트
            vault.accrued_interest = vault.accrued_interest
                .checked_add(&interest)
                .ok_or(Error::<T>::ArithmeticError)?;

            vault.last_update_block = current_block;

            // 이벤트 발행
            if !interest.is_zero() {
                let new_total_debt = vault.debt_amount
                    .checked_add(&vault.accrued_interest)
                    .ok_or(Error::<T>::ArithmeticError)?;

                Self::deposit_event(Event::InterestAccrued {
                    loan_id,
                    amount: interest,
                    new_total_debt,
                });
            }

            Ok(())
        }

        /// 청산 담보 계산
        ///
        /// # 매개변수
        /// - `repay_amount`: 상환 금액
        /// - `asset_price`: 자산 가격
        /// - `incentive`: 청산 인센티브 (basis points)
        ///
        /// # 반환값
        /// 청산할 담보 수량
        fn calculate_liquidation_collateral(
            repay_amount: BalanceOf<T>,
            asset_price: BalanceOf<T>,
            incentive: u32,
        ) -> Result<BalanceOf<T>, DispatchError> {
            // collateral = (repay_amount / price) * (1 + incentive)
            // incentive는 basis points (500 = 5%)

            let repay_amount_u128: u128 = repay_amount.saturated_into();
            let asset_price_u128: u128 = asset_price.saturated_into();
            let basis_points = 10000u32;
            let incentive_multiplier = basis_points
                .checked_add(incentive)
                .ok_or(Error::<T>::ArithmeticError)?;

            let collateral_u128 = repay_amount_u128
                .checked_mul(incentive_multiplier.into())
                .and_then(|x| x.checked_div(asset_price_u128))
                .and_then(|x| x.checked_div(basis_points.into()))
                .ok_or(Error::<T>::ArithmeticError)?;

            let collateral: BalanceOf<T> = collateral_u128.saturated_into();

            Ok(collateral)
        }

        /// 자산 가격 조회 (모의용, Brain 연동 전)
        ///
        /// # 매개변수
        /// - `asset_id`: 자산 ID
        ///
        /// # 반환값
        /// 자산 가격
        fn get_asset_price(asset_id: AssetId) -> BalanceOf<T> {
            AssetPrices::<T>::get(asset_id)
                .or_else(|| {
                    // 기본 가격: 2000 (예: ETH = $2000)
                    Some(2000u32.into())
                })
                .unwrap_or_else(|| 2000u32.into())
        }

        /// 기여도 점수 조회 또는 생성
        ///
        /// # 매개변수
        /// - `account`: 계정
        ///
        /// # 반환값
        /// 기여도 점수 상세 정보
        fn get_or_create_contribution_score(
            account: &T::AccountId,
        ) -> ContributionScoreDetails {
            ContributionScores::<T>::get(account)
        }
    }
}

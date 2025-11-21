//! # Stablecoin Lending Pallet Tests
//!
//! 8개의 핵심 테스트 케이스를 제공합니다.

use crate::{mock::*, Error, Event, VaultStatus};
use frame_support::{assert_noop, assert_ok};

/// 테스트 1: 기여도 점수 계산 테스트
///
/// CS = 0.30 × LP + 0.25 × TV + 0.20 × GP + 0.15 × HD + 0.10 × TS
///
/// 예시: LP=80, TV=70, GP=90, HD=60, TS=50
/// CS = 0.30(80) + 0.25(70) + 0.20(90) + 0.15(60) + 0.10(50)
///    = 24 + 17.5 + 18 + 9 + 5
///    = 73.5 ≈ 73
#[test]
fn test_contribution_score_calculation() {
	new_test_ext().execute_with(|| {
		// Given: 기여도 구성 요소
		let lp = 80; // Liquidity Provision
		let tv = 70; // Total Value Locked
		let gp = 90; // Governance Participation
		let hd = 60; // Historical Debt
		let ts = 50; // Tenure Score

		// When: CS 계산
		let cs = StablecoinLending::calculate_contribution_score(lp, tv, gp, hd, ts);

		// Then: 예상 결과와 비교
		// CS = 0.30(80) + 0.25(70) + 0.20(90) + 0.15(60) + 0.10(50)
		//    = 24 + 17 + 18 + 9 + 5 = 73 (정수 연산)
		assert_eq!(cs, 73);

		// Edge case: 모든 값이 100일 때
		let cs_max = StablecoinLending::calculate_contribution_score(100, 100, 100, 100, 100);
		assert_eq!(cs_max, 100);

		// Edge case: 모든 값이 0일 때
		let cs_min = StablecoinLending::calculate_contribution_score(0, 0, 0, 0, 0);
		assert_eq!(cs_min, 0);
	});
}

/// 테스트 2: 동적 담보율 계산 테스트
///
/// CR_dynamic = 150% - CS (범위: 50%-150%)
///
/// 예시: CS=73, BaseRatio=150, MinRatio=50
/// CR_dynamic = 150 - 73 = 77%
#[test]
fn test_dynamic_collateral_ratio() {
	new_test_ext().execute_with(|| {
		// Given: 기여도 점수 73
		let cs = 73;
		let base_ratio = 150;
		let min_ratio = 50;

		// When: CR_dynamic 계산
		let cr_dynamic =
			StablecoinLending::calculate_dynamic_collateral_ratio(cs, base_ratio, min_ratio);

		// Then: 예상 결과 77%
		assert_eq!(cr_dynamic, 77);

		// Edge case: CS=0 → CR_dynamic=150%
		let cr_max =
			StablecoinLending::calculate_dynamic_collateral_ratio(0, base_ratio, min_ratio);
		assert_eq!(cr_max, 150);

		// Edge case: CS=100 → CR_dynamic=50%
		let cr_min =
			StablecoinLending::calculate_dynamic_collateral_ratio(100, base_ratio, min_ratio);
		assert_eq!(cr_min, 50);

		// Edge case: CS=120 (초과) → CR_dynamic=50% (최소값으로 제한)
		let cr_over =
			StablecoinLending::calculate_dynamic_collateral_ratio(120, base_ratio, min_ratio);
		assert_eq!(cr_over, 50);
	});
}

/// 테스트 3: 대출 실행 성공 테스트
///
/// 담보를 예치하고 스테이블코인을 대출받습니다.
#[test]
fn test_execute_loan_works() {
	new_test_ext().execute_with(|| {
		// Given: ALICE의 CS = 80, BTC 가격 = $50,000
		// CR_dynamic = 150 - 80 = 70%
		// 담보: 1 BTC (1_000_000_000 satoshis, 9 decimals)
		// 담보 가치: $50,000
		// 최대 대출: $50,000 × 100 / 70 = $71,428.57

		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 1_000_000_000u128; // 1 BTC
		let loan_amount = 50_000_000_000_000u128; // $50,000 (9 decimals)

		// When: 대출 실행
		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			asset_id,
			collateral_amount,
			loan_amount
		));

		// Then: 금고 생성 확인
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.borrower, borrower);
		assert_eq!(vault.collateral_asset_id, asset_id);
		assert_eq!(vault.collateral_amount, collateral_amount);
		assert_eq!(vault.debt_amount, loan_amount);
		assert_eq!(vault.collateral_ratio, 70); // CR_dynamic
		assert_eq!(vault.status, VaultStatus::Active);

		// 사용자 대출 목록 확인
		let user_loans = StablecoinLending::user_loans(borrower);
		assert_eq!(user_loans.len(), 1);
		assert_eq!(user_loans[0], 0);

		// 총 공급량 확인
		assert_eq!(StablecoinLending::total_supply(), loan_amount);

		// 이벤트 확인
		System::assert_last_event(
			Event::LoanIssued {
				loan_id: 0,
				borrower,
				collateral_amount,
				loan_amount,
				collateral_ratio: 70,
			}
			.into(),
		);
	});
}

/// 테스트 4: 담보 부족 시 대출 실패 테스트
///
/// 담보가 부족하면 대출이 실패해야 합니다.
#[test]
fn test_insufficient_collateral_fails() {
	new_test_ext().execute_with(|| {
		// Given: ALICE의 CS = 80, BTC 가격 = $50,000
		// CR_dynamic = 150 - 80 = 70%
		// 담보: 1 BTC (1_000_000_000 satoshis)
		// 담보 가치: $50,000
		// 최대 대출: $50,000 × 100 / 70 = $71,428.57

		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 1_000_000_000u128; // 1 BTC
		let excessive_loan = 80_000_000_000_000u128; // $80,000 (초과)

		// When & Then: 대출 실행 실패
		assert_noop!(
			StablecoinLending::execute_loan(
				RuntimeOrigin::signed(borrower),
				asset_id,
				collateral_amount,
				excessive_loan
			),
			Error::<Test>::InsufficientCollateral
		);
	});
}

/// 테스트 5: Stage 1 - DeRisk 활성화 테스트
///
/// 담보율이 145%-150% 범위에 진입하면 DeRisk 상태로 전환됩니다.
#[test]
fn test_stage1_derisk_activation() {
	new_test_ext().execute_with(|| {
		// Given: ALICE가 대출 실행
		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 1_000_000_000u128; // 1 BTC
		let loan_amount = 30_000_000_000_000u128; // $30,000

		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			asset_id,
			collateral_amount,
			loan_amount
		));

		// 현재 담보율: $50,000 / $30,000 × 100 = 166.67%
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::Active);

		// When: BTC 가격 하락 → $45,000 (담보율 = 150%)
		set_asset_price(BTC_ASSET_ID, 45_000_000_000);

		// 블록 진행하여 모니터링 실행
		run_to_block(2);

		// Then: 상태가 Active로 유지 (경계값)
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::Active);

		// When: BTC 가격 추가 하락 → $44,500 (담보율 = 148.33%)
		set_asset_price(BTC_ASSET_ID, 44_500_000_000);
		run_to_block(3);

		// Then: 상태가 DeRisk로 전환
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::DeRisk);
	});
}

/// 테스트 6: Stage 2 - 부분 청산 테스트
///
/// 담보율이 140%-145% 범위에 진입하면 PartialLiquid 상태로 전환되고,
/// 부분 청산을 실행할 수 있습니다.
#[test]
fn test_stage2_partial_liquidation() {
	new_test_ext().execute_with(|| {
		// Given: ALICE가 대출 실행
		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 1_000_000_000u128; // 1 BTC
		let loan_amount = 30_000_000_000_000u128; // $30,000

		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			asset_id,
			collateral_amount,
			loan_amount
		));

		// When: BTC 가격 하락 → $43,000 (담보율 = 143.33%)
		set_asset_price(BTC_ASSET_ID, 43_000_000_000);
		run_to_block(2);

		// Then: 상태가 PartialLiquid로 전환
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::PartialLiquid);

		// When: 부분 청산 실행 (청산자: BOB)
		let liquidator = BOB;
		assert_ok!(StablecoinLending::partial_liquidate(RuntimeOrigin::signed(liquidator), 0));

		// Then: 부채가 50% 감소
		let vault = StablecoinLending::vaults(0).unwrap();
		let expected_remaining_debt = loan_amount / 2; // 50% 청산
		assert_eq!(vault.debt_amount, expected_remaining_debt);

		// 이벤트 확인
		assert!(System::events().iter().any(|record| {
			matches!(
				record.event,
				RuntimeEvent::StablecoinLending(Event::PartialLiquidation { loan_id: 0, .. })
			)
		}));
	});
}

/// 테스트 7: Stage 3 - 강제 청산 테스트
///
/// 담보율이 140% 미만으로 떨어지면 EmergencyStop 상태로 전환되고,
/// 강제 청산을 실행할 수 있습니다.
#[test]
fn test_stage3_emergency_stop() {
	new_test_ext().execute_with(|| {
		// Given: ALICE가 대출 실행
		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 1_000_000_000u128; // 1 BTC
		let loan_amount = 30_000_000_000_000u128; // $30,000

		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			asset_id,
			collateral_amount,
			loan_amount
		));

		// When: BTC 가격 급락 → $40,000 (담보율 = 133.33%)
		set_asset_price(BTC_ASSET_ID, 40_000_000_000);
		run_to_block(2);

		// Then: 상태가 EmergencyStop으로 전환
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::EmergencyStop);

		// When: 강제 청산 실행 (청산자: BOB)
		let liquidator = BOB;
		assert_ok!(StablecoinLending::emergency_liquidate(RuntimeOrigin::signed(liquidator), 0));

		// Then: 금고 삭제됨
		assert!(StablecoinLending::vaults(0).is_none());

		// 사용자 대출 목록에서 제거됨
		let user_loans = StablecoinLending::user_loans(borrower);
		assert_eq!(user_loans.len(), 0);

		// 이벤트 확인
		assert!(System::events().iter().any(|record| {
			matches!(
				record.event,
				RuntimeEvent::StablecoinLending(Event::EmergencyLiquidation { loan_id: 0 })
			)
		}));
		assert!(System::events().iter().any(|record| {
			matches!(
				record.event,
				RuntimeEvent::StablecoinLending(Event::VaultClosed { loan_id: 0 })
			)
		}));
	});
}

/// 테스트 8: 금고 상태 전환 테스트
///
/// 담보 추가/가격 변동에 따른 금고 상태 전환을 테스트합니다.
#[test]
fn test_vault_status_transitions() {
	new_test_ext().execute_with(|| {
		// Given: ALICE가 대출 실행
		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 1_000_000_000u128; // 1 BTC
		let loan_amount = 30_000_000_000_000u128; // $30,000

		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			asset_id,
			collateral_amount,
			loan_amount
		));

		// 초기 상태: Active (담보율 = 166.67%)
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::Active);

		// When: 가격 하락 → DeRisk
		set_asset_price(BTC_ASSET_ID, 44_500_000_000); // 담보율 = 148.33%
		run_to_block(2);
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::DeRisk);

		// When: 가격 추가 하락 → PartialLiquid
		set_asset_price(BTC_ASSET_ID, 43_000_000_000); // 담보율 = 143.33%
		run_to_block(3);
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::PartialLiquid);

		// When: 담보 추가 → Active로 복귀
		let additional_collateral = 500_000_000u128; // 0.5 BTC 추가
		assert_ok!(StablecoinLending::add_collateral(
			RuntimeOrigin::signed(borrower),
			0,
			additional_collateral
		));

		// 새 담보율 = (1.5 BTC × $43,000) / $30,000 × 100 = 215%
		run_to_block(4);
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.status, VaultStatus::Active);

		// 이벤트 확인: 상태 전환 이벤트 발생
		let status_change_events: Vec<_> = System::events()
			.iter()
			.filter(|record| {
				matches!(
					record.event,
					RuntimeEvent::StablecoinLending(Event::VaultStatusChanged { .. })
				)
			})
			.collect();

		// Active → DeRisk, DeRisk → PartialLiquid, PartialLiquid → Active
		assert_eq!(status_change_events.len(), 3);
	});
}

/// 추가 테스트: 대출 상환 테스트
#[test]
fn test_loan_repayment() {
	new_test_ext().execute_with(|| {
		// Given: ALICE가 대출 실행
		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 1_000_000_000u128; // 1 BTC
		let loan_amount = 30_000_000_000_000u128; // $30,000

		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			asset_id,
			collateral_amount,
			loan_amount
		));

		// When: 부분 상환 ($10,000)
		let repay_amount = 10_000_000_000_000u128;
		assert_ok!(StablecoinLending::repay_loan(RuntimeOrigin::signed(borrower), 0, repay_amount));

		// Then: 부채 감소 확인
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.debt_amount, loan_amount - repay_amount);

		// When: 전액 상환
		let remaining_debt = vault.debt_amount;
		assert_ok!(StablecoinLending::repay_loan(
			RuntimeOrigin::signed(borrower),
			0,
			remaining_debt
		));

		// Then: 금고 폐쇄됨
		assert!(StablecoinLending::vaults(0).is_none());

		// 이벤트 확인
		assert!(System::events().iter().any(|record| {
			matches!(
				record.event,
				RuntimeEvent::StablecoinLending(Event::VaultClosed { loan_id: 0 })
			)
		}));
	});
}

/// 추가 테스트: 담보 인출 테스트
#[test]
fn test_collateral_withdrawal() {
	new_test_ext().execute_with(|| {
		// Given: ALICE가 대출 실행
		let borrower = ALICE;
		let asset_id = BTC_ASSET_ID;
		let collateral_amount = 2_000_000_000u128; // 2 BTC
		let loan_amount = 30_000_000_000_000u128; // $30,000

		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			asset_id,
			collateral_amount,
			loan_amount
		));

		// 현재 담보율: (2 BTC × $50,000) / $30,000 × 100 = 333.33%

		// When: 담보 인출 (0.5 BTC) - 성공
		let withdraw_amount = 500_000_000u128;
		assert_ok!(StablecoinLending::withdraw_collateral(
			RuntimeOrigin::signed(borrower),
			0,
			withdraw_amount
		));

		// Then: 담보 감소 확인
		let vault = StablecoinLending::vaults(0).unwrap();
		assert_eq!(vault.collateral_amount, collateral_amount - withdraw_amount);

		// When: 과도한 담보 인출 시도 (1.0 BTC) - 실패
		// 인출 후 담보율 = (0.5 BTC × $50,000) / $30,000 × 100 = 83.33% < 150%
		let excessive_withdraw = 1_000_000_000u128;
		assert_noop!(
			StablecoinLending::withdraw_collateral(
				RuntimeOrigin::signed(borrower),
				0,
				excessive_withdraw
			),
			Error::<Test>::CannotWithdrawCollateral
		);
	});
}

/// 추가 테스트: 기여도 구성 요소 업데이트 테스트
#[test]
fn test_contribution_components_update() {
	new_test_ext().execute_with(|| {
		// Given: BOB의 기여도 구성 요소
		let account = BOB;
		let components = create_contribution_components(80, 70, 90, 60, 50);

		// When: 관리자가 기여도 구성 요소 업데이트
		assert_ok!(StablecoinLending::update_contribution_components(
			RuntimeOrigin::root(),
			account,
			components.clone()
		));

		// Then: 구성 요소 저장 확인
		let stored_components = StablecoinLending::contribution_components(account);
		assert_eq!(stored_components.liquidity_provision, 80);
		assert_eq!(stored_components.total_value_locked, 70);
		assert_eq!(stored_components.governance_participation, 90);
		assert_eq!(stored_components.historical_debt, 60);
		assert_eq!(stored_components.tenure_score, 50);

		// CS 자동 계산 확인
		let cs = StablecoinLending::contribution_scores(account);
		let expected_cs = StablecoinLending::calculate_contribution_score(80, 70, 90, 60, 50);
		assert_eq!(cs, expected_cs);

		// 이벤트 확인
		assert!(System::events().iter().any(|record| {
			matches!(
				record.event,
				RuntimeEvent::StablecoinLending(Event::ContributionComponentsUpdated {
					account: acc
				}) if acc == account
			)
		}));
	});
}

/// 추가 테스트: 자산 가격 업데이트 테스트
#[test]
fn test_asset_price_update() {
	new_test_ext().execute_with(|| {
		// Given: 초기 BTC 가격 = $50,000
		let asset_id = BTC_ASSET_ID;
		let old_price = StablecoinLending::asset_prices(asset_id);
		assert_eq!(old_price, 50_000_000_000);

		// When: 관리자가 가격 업데이트 ($55,000)
		let new_price = 55_000_000_000u128;
		assert_ok!(StablecoinLending::update_asset_price(
			RuntimeOrigin::root(),
			asset_id,
			new_price
		));

		// Then: 가격 업데이트 확인
		assert_eq!(StablecoinLending::asset_prices(asset_id), new_price);

		// 이벤트 확인
		System::assert_last_event(
			Event::AssetPriceUpdated { asset_id, old_price, new_price }.into(),
		);
	});
}

/// 추가 테스트: 여러 대출 관리 테스트
#[test]
fn test_multiple_loans() {
	new_test_ext().execute_with(|| {
		// Given: ALICE가 여러 대출 실행
		let borrower = ALICE;

		// 첫 번째 대출 (BTC)
		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			BTC_ASSET_ID,
			1_000_000_000u128,
			30_000_000_000_000u128
		));

		// 두 번째 대출 (ETH)
		assert_ok!(StablecoinLending::execute_loan(
			RuntimeOrigin::signed(borrower),
			ETH_ASSET_ID,
			10_000_000_000u128, // 10 ETH
			20_000_000_000_000u128 // $20,000
		));

		// Then: 사용자 대출 목록 확인
		let user_loans = StablecoinLending::user_loans(borrower);
		assert_eq!(user_loans.len(), 2);
		assert_eq!(user_loans[0], 0);
		assert_eq!(user_loans[1], 1);

		// 총 부채 확인
		let total_debt = StablecoinLending::get_total_debt(&borrower);
		assert_eq!(total_debt, 50_000_000_000_000u128); // $50,000

		// 첫 번째 대출 상환
		assert_ok!(StablecoinLending::repay_loan(
			RuntimeOrigin::signed(borrower),
			0,
			30_000_000_000_000u128
		));

		// Then: 사용자 대출 목록 업데이트 확인
		let user_loans = StablecoinLending::user_loans(borrower);
		assert_eq!(user_loans.len(), 1);
		assert_eq!(user_loans[0], 1);
	});
}

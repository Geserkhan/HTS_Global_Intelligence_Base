use crate::{mock::*, Error, Event, VaultStatus};
use frame_support::{assert_noop, assert_ok};

/// 테스트 1: CS (기여도 점수) 계산
/// 공식: CS = 0.30×LP + 0.25×TV + 0.20×GP + 0.15×HD + 0.10×TS
#[test]
fn test_contribution_score_calculation() {
    new_test_ext().execute_with(|| {
        // 테스트 케이스 1: 모든 항목 50점
        let cs1 = StablecoinLending::calculate_contribution_score(50, 50, 50, 50, 50).unwrap();
        assert_eq!(cs1, 50, "모든 항목 50점일 때 CS는 50이어야 함");

        // 테스트 케이스 2: 모든 항목 100점
        let cs2 = StablecoinLending::calculate_contribution_score(100, 100, 100, 100, 100).unwrap();
        assert_eq!(cs2, 100, "모든 항목 100점일 때 CS는 100이어야 함");

        // 테스트 케이스 3: 모든 항목 0점
        let cs3 = StablecoinLending::calculate_contribution_score(0, 0, 0, 0, 0).unwrap();
        assert_eq!(cs3, 0, "모든 항목 0점일 때 CS는 0이어야 함");

        // 테스트 케이스 4: 가중치 검증
        // LP=100, TV=0, GP=0, HD=0, TS=0 → CS = 0.30×100 = 30
        let cs4 = StablecoinLending::calculate_contribution_score(100, 0, 0, 0, 0).unwrap();
        assert_eq!(cs4, 30, "LP만 100점일 때 CS는 30이어야 함");

        // 테스트 케이스 5: 복합 점수
        // LP=80, TV=60, GP=70, HD=50, TS=40
        // CS = 0.30×80 + 0.25×60 + 0.20×70 + 0.15×50 + 0.10×40
        //    = 24 + 15 + 14 + 7.5 + 4 = 64.5 ≈ 64
        let cs5 = StablecoinLending::calculate_contribution_score(80, 60, 70, 50, 40).unwrap();
        assert_eq!(cs5, 64, "복합 점수 계산 검증");
    });
}

/// 테스트 2: CR_dynamic (동적 담보율) 계산
/// 공식: CR_dynamic = 150% - CS (범위: 50%-150%)
#[test]
fn test_dynamic_collateral_ratio() {
    new_test_ext().execute_with(|| {
        // 테스트 케이스 1: CS=0 → CR=150% (15000 basis points)
        let cr1 = StablecoinLending::calculate_dynamic_collateral_ratio(0).unwrap();
        assert_eq!(cr1, 15000, "CS=0일 때 CR은 150%이어야 함");

        // 테스트 케이스 2: CS=50 → CR=100% (10000 basis points)
        let cr2 = StablecoinLending::calculate_dynamic_collateral_ratio(50).unwrap();
        assert_eq!(cr2, 10000, "CS=50일 때 CR은 100%이어야 함");

        // 테스트 케이스 3: CS=100 → CR=50% (5000 basis points, 최소값)
        let cr3 = StablecoinLending::calculate_dynamic_collateral_ratio(100).unwrap();
        assert_eq!(cr3, 5000, "CS=100일 때 CR은 50%이어야 함");

        // 테스트 케이스 4: CS=25 → CR=125% (12500 basis points)
        let cr4 = StablecoinLending::calculate_dynamic_collateral_ratio(25).unwrap();
        assert_eq!(cr4, 12500, "CS=25일 때 CR은 125%이어야 함");

        // 테스트 케이스 5: CS=75 → CR=75% (7500 basis points)
        let cr5 = StablecoinLending::calculate_dynamic_collateral_ratio(75).unwrap();
        assert_eq!(cr5, 7500, "CS=75일 때 CR은 75%이어야 함");
    });
}

/// 테스트 3: 대출 실행
#[test]
fn test_execute_loan() {
    new_test_ext().execute_with(|| {
        // 자산 가격 설정: 1 ETH = 2000 USD
        set_asset_price(ETH, 2000);

        // 기여도 점수 설정: CS=50 → CR=100%
        set_default_contribution_score(ALICE);

        // 담보: 10 ETH = 20,000 USD
        // CR=100% → 최대 대출: 20,000 USD
        let collateral_amount = 10;
        let loan_amount = 15000; // 20,000보다 작게 설정

        // 대출 실행
        assert_ok!(StablecoinLending::execute_loan(
            RuntimeOrigin::signed(ALICE),
            ETH,
            collateral_amount,
            loan_amount
        ));

        // 검증: 대출 카운트 증가
        assert_eq!(StablecoinLending::loan_count(), 1);

        // 검증: 금고 생성
        let vault = StablecoinLending::vaults(0).unwrap();
        assert_eq!(vault.borrower, ALICE);
        assert_eq!(vault.collateral_amount, collateral_amount);
        assert_eq!(vault.debt_amount, loan_amount);
        assert_eq!(vault.status, VaultStatus::Active);

        // 검증: 담보 예치 (Reserved)
        assert_eq!(Balances::reserved_balance(ALICE), collateral_amount);

        // 검증: 총 공급 증가
        assert_eq!(StablecoinLending::total_supply(), loan_amount);

        // 검증: 이벤트 발행
        System::assert_has_event(
            Event::LoanIssued {
                loan_id: 0,
                borrower: ALICE,
                collateral_amount,
                loan_amount,
                collateral_ratio: 10000, // CS=50 → CR=100%
            }
            .into(),
        );
    });
}

/// 테스트 4: 담보 추가
#[test]
fn test_add_collateral() {
    new_test_ext().execute_with(|| {
        // 초기 설정
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 대출 생성
        let initial_collateral = 10;
        let loan_amount = 15000;
        let loan_id = create_loan(ALICE, ETH, initial_collateral, loan_amount).unwrap();

        // 담보 추가
        let additional_collateral = 5;
        assert_ok!(StablecoinLending::add_collateral(
            RuntimeOrigin::signed(ALICE),
            loan_id,
            additional_collateral
        ));

        // 검증: 담보 금액 업데이트
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(
            vault.collateral_amount,
            initial_collateral + additional_collateral
        );

        // 검증: 담보율 개선
        // 담보 가치: 15 ETH × 2000 = 30,000 USD
        // 부채: 15,000 USD
        // CR = 30,000 / 15,000 × 100% = 200%
        assert!(vault.collateral_ratio > 15000); // 150%보다 큼

        // 검증: 예치된 담보 증가
        assert_eq!(
            Balances::reserved_balance(ALICE),
            initial_collateral + additional_collateral
        );

        // 검증: 이벤트 발행
        System::assert_has_event(
            Event::CollateralAdded {
                loan_id,
                borrower: ALICE,
                amount: additional_collateral,
                new_total: initial_collateral + additional_collateral,
            }
            .into(),
        );
    });
}

/// 테스트 5: 대출 상환
#[test]
fn test_repay_loan() {
    new_test_ext().execute_with(|| {
        // 초기 설정
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 대출 생성
        let collateral_amount = 10;
        let loan_amount = 15000;
        let loan_id = create_loan(ALICE, ETH, collateral_amount, loan_amount).unwrap();

        // 부분 상환
        let repay_amount = 5000;
        assert_ok!(StablecoinLending::repay_loan(
            RuntimeOrigin::signed(ALICE),
            loan_id,
            repay_amount
        ));

        // 검증: 부채 감소
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(vault.debt_amount, loan_amount - repay_amount);

        // 검증: 총 공급 감소
        assert_eq!(
            StablecoinLending::total_supply(),
            loan_amount - repay_amount
        );

        // 검증: 이벤트 발행
        System::assert_has_event(
            Event::LoanRepaid {
                loan_id,
                borrower: ALICE,
                amount: repay_amount,
                remaining_debt: loan_amount - repay_amount,
            }
            .into(),
        );

        // 전액 상환
        let remaining_debt = vault.debt_amount;
        assert_ok!(StablecoinLending::repay_loan(
            RuntimeOrigin::signed(ALICE),
            loan_id,
            remaining_debt
        ));

        // 검증: 금고 삭제
        assert!(StablecoinLending::vaults(loan_id).is_none());

        // 검증: 담보 반환
        assert_eq!(Balances::reserved_balance(ALICE), 0);

        // 검증: 총 공급 = 0
        assert_eq!(StablecoinLending::total_supply(), 0);
    });
}

/// 테스트 6: Stage 1 De-Risk 발동
/// 담보율이 145%-150% 범위일 때 DeRisk 상태로 변경
#[test]
fn test_stage1_derisk() {
    new_test_ext().execute_with(|| {
        // 초기 설정
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 대출 생성
        // 담보: 10 ETH × 2000 = 20,000 USD
        // 대출: 13,500 USD
        // 초기 CR = 20,000 / 13,500 × 100% ≈ 148%
        let collateral_amount = 10;
        let loan_amount = 13500;
        let loan_id = create_loan(ALICE, ETH, collateral_amount, loan_amount).unwrap();

        // 초기 상태 확인
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(vault.status, VaultStatus::Active);

        // 가격 하락 시뮬레이션: 1 ETH = 1970 USD
        // 새 담보 가치: 10 ETH × 1970 = 19,700 USD
        // 새 CR = 19,700 / 13,500 × 100% ≈ 145.9%
        set_asset_price(ETH, 1970);

        // on_initialize 호출 (모니터링 트리거)
        run_to_block(2);

        // 검증: DeRisk 상태로 변경
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(vault.status, VaultStatus::DeRisk);

        // 검증: 이벤트 발행
        System::assert_has_event(
            Event::VaultStatusChanged {
                loan_id,
                old_status: VaultStatus::Active,
                new_status: VaultStatus::DeRisk,
                current_ratio: vault.collateral_ratio,
            }
            .into(),
        );
    });
}

/// 테스트 7: Stage 2 부분 청산
/// 담보율이 140%-145% 범위일 때 PartialLiquid 상태로 변경되고 부분 청산 가능
#[test]
fn test_stage2_partial_liquidation() {
    new_test_ext().execute_with(|| {
        // 초기 설정
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 대출 생성
        // 담보: 10 ETH × 2000 = 20,000 USD
        // 대출: 14,000 USD
        // 초기 CR = 20,000 / 14,000 × 100% ≈ 142.8%
        let collateral_amount = 10;
        let loan_amount = 14000;
        let loan_id = create_loan(ALICE, ETH, collateral_amount, loan_amount).unwrap();

        // 가격 하락 시뮬레이션: 1 ETH = 1960 USD
        // 새 담보 가치: 10 ETH × 1960 = 19,600 USD
        // 새 CR = 19,600 / 14,000 × 100% = 140%
        set_asset_price(ETH, 1960);

        // on_initialize 호출 (모니터링 트리거)
        run_to_block(2);

        // 검증: PartialLiquid 상태로 변경
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(vault.status, VaultStatus::PartialLiquid);

        // 부분 청산 실행 (BOB이 청산자)
        let repay_amount = 5000; // 부채의 일부 상환
        assert_ok!(StablecoinLending::partial_liquidate(
            RuntimeOrigin::signed(BOB),
            loan_id,
            repay_amount
        ));

        // 검증: 부채 감소
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(vault.debt_amount, loan_amount - repay_amount);

        // 검증: 청산 인센티브 포함 담보 이전
        // collateral_liquidated = (repay_amount / price) × (1 + incentive)
        // = (5000 / 1960) × 1.05 ≈ 2.68
        let expected_collateral_liquidated = (repay_amount * 105) / (1960 * 100);
        assert_eq!(
            vault.collateral_amount,
            collateral_amount - expected_collateral_liquidated
        );

        // 검증: 이벤트 발행
        System::assert_has_event(
            Event::PartialLiquidation {
                loan_id,
                liquidator: BOB,
                collateral_liquidated: expected_collateral_liquidated,
                debt_repaid: repay_amount,
            }
            .into(),
        );
    });
}

/// 테스트 8: Stage 3 긴급 청산
/// 담보율이 140% 미만일 때 EmergencyStop 상태로 변경되고 전체 청산 가능
#[test]
fn test_stage3_emergency_stop() {
    new_test_ext().execute_with(|| {
        // 초기 설정
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 대출 생성
        // 담보: 10 ETH × 2000 = 20,000 USD
        // 대출: 14,300 USD
        // 초기 CR = 20,000 / 14,300 × 100% ≈ 139.8%
        let collateral_amount = 10;
        let loan_amount = 14300;
        let loan_id = create_loan(ALICE, ETH, collateral_amount, loan_amount).unwrap();

        // on_initialize 호출 (모니터링 트리거)
        run_to_block(2);

        // 검증: EmergencyStop 상태로 변경
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(vault.status, VaultStatus::EmergencyStop);

        // 긴급 청산 실행 (CHARLIE가 청산자)
        assert_ok!(StablecoinLending::emergency_liquidate(
            RuntimeOrigin::signed(CHARLIE),
            loan_id
        ));

        // 검증: 금고 삭제
        assert!(StablecoinLending::vaults(loan_id).is_none());

        // 검증: 전체 담보 이전
        // (실제로는 청산자가 담보를 받았는지 확인해야 하지만,
        // mock에서는 단순히 금고가 삭제되었는지만 확인)

        // 검증: 이벤트 발행
        System::assert_has_event(
            Event::EmergencyLiquidation {
                loan_id,
                liquidator: CHARLIE,
                collateral_liquidated: collateral_amount,
                debt_repaid: loan_amount,
            }
            .into(),
        );
    });
}

/// 테스트 9: 담보 부족 시 대출 실패
#[test]
fn test_insufficient_collateral() {
    new_test_ext().execute_with(|| {
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 담보: 10 ETH × 2000 = 20,000 USD
        // CR=100% → 최대 대출: 20,000 USD
        // 대출 요청: 25,000 USD (초과)
        let collateral_amount = 10;
        let loan_amount = 25000;

        // 대출 실패 확인
        assert_noop!(
            StablecoinLending::execute_loan(
                RuntimeOrigin::signed(ALICE),
                ETH,
                collateral_amount,
                loan_amount
            ),
            Error::<Test>::InsufficientCollateral
        );
    });
}

/// 테스트 10: 권한 없는 사용자의 담보 추가 시도
#[test]
fn test_unauthorized_add_collateral() {
    new_test_ext().execute_with(|| {
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // ALICE가 대출 생성
        let loan_id = create_loan(ALICE, ETH, 10, 15000).unwrap();

        // BOB이 담보 추가 시도 (실패해야 함)
        assert_noop!(
            StablecoinLending::add_collateral(RuntimeOrigin::signed(BOB), loan_id, 5),
            Error::<Test>::Unauthorized
        );
    });
}

/// 테스트 11: 이자 발생
#[test]
fn test_interest_accrual() {
    new_test_ext().execute_with(|| {
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 대출 생성
        let loan_id = create_loan(ALICE, ETH, 10, 15000).unwrap();

        // 초기 누적 이자 확인
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        assert_eq!(vault.accrued_interest, 0);

        // 1년치 블록 진행 (5,256,000 블록)
        run_to_block(5_256_001);

        // 이자 확인
        let vault = StablecoinLending::vaults(loan_id).unwrap();
        // 연 5% 이자율 → 15,000 × 5% = 750
        assert!(vault.accrued_interest > 0);
        assert!(vault.accrued_interest <= 750); // 정확한 계산은 블록 수에 따라 달라질 수 있음
    });
}

/// 테스트 12: 높은 CS 점수로 낮은 담보율 적용
#[test]
fn test_high_contribution_score_lower_collateral_ratio() {
    new_test_ext().execute_with(|| {
        set_asset_price(ETH, 2000);

        // 높은 CS 점수 설정: CS=90 → CR=60%
        set_high_contribution_score(ALICE);

        // 담보: 10 ETH × 2000 = 20,000 USD
        // CR=60% → 최대 대출: 20,000 / 0.6 ≈ 33,333 USD
        let collateral_amount = 10;
        let loan_amount = 30000; // 33,333보다 작게 설정

        // 대출 성공
        assert_ok!(StablecoinLending::execute_loan(
            RuntimeOrigin::signed(ALICE),
            ETH,
            collateral_amount,
            loan_amount
        ));

        // 검증: 낮은 담보율로 대출 가능
        let vault = StablecoinLending::vaults(0).unwrap();
        assert!(vault.collateral_ratio < 10000); // 100%보다 낮음
    });
}

/// 테스트 13: 청산 조건 미충족 시 청산 실패
#[test]
fn test_liquidation_condition_not_met() {
    new_test_ext().execute_with(|| {
        set_asset_price(ETH, 2000);
        set_default_contribution_score(ALICE);

        // 정상 대출 생성 (CR이 높음)
        let loan_id = create_loan(ALICE, ETH, 10, 10000).unwrap();

        // 부분 청산 시도 (실패해야 함 - Active 상태)
        assert_noop!(
            StablecoinLending::partial_liquidate(RuntimeOrigin::signed(BOB), loan_id, 1000),
            Error::<Test>::LiquidationConditionNotMet
        );

        // 긴급 청산 시도 (실패해야 함 - Active 상태)
        assert_noop!(
            StablecoinLending::emergency_liquidate(RuntimeOrigin::signed(BOB), loan_id),
            Error::<Test>::LiquidationConditionNotMet
        );
    });
}

/// 테스트 14: 기여도 점수 업데이트
#[test]
fn test_contribution_score_update() {
    new_test_ext().execute_with(|| {
        // 초기 점수 설정
        set_contribution_score(ALICE, 50, 50, 50, 50, 50);

        // 점수 확인
        let score_details = StablecoinLending::contribution_scores(ALICE);
        assert_eq!(score_details.total_score, 50);

        // 점수 업데이트
        set_contribution_score(ALICE, 80, 70, 60, 50, 40);

        // 새 점수 확인
        let score_details = StablecoinLending::contribution_scores(ALICE);
        assert_eq!(score_details.liquidity_provision, 80);
        assert_eq!(score_details.total_value_locked, 70);
        assert_eq!(score_details.governance_participation, 60);
        assert_eq!(score_details.historical_debt, 50);
        assert_eq!(score_details.tenure_score, 40);

        // CS = 0.30×80 + 0.25×70 + 0.20×60 + 0.15×50 + 0.10×40
        //    = 24 + 17.5 + 12 + 7.5 + 4 = 65
        assert_eq!(score_details.total_score, 65);

        // 이벤트 확인
        System::assert_has_event(
            Event::ContributionScoreUpdated {
                account: ALICE,
                old_score: 50,
                new_score: 65,
            }
            .into(),
        );
    });
}

/// 테스트 15: 잘못된 기여도 점수 업데이트 시도
#[test]
fn test_invalid_contribution_score_update() {
    new_test_ext().execute_with(|| {
        // 범위를 벗어난 점수 (101점)
        assert_noop!(
            StablecoinLending::update_contribution_score(
                RuntimeOrigin::root(),
                ALICE,
                101, // 범위 초과
                50,
                50,
                50,
                50
            ),
            Error::<Test>::InvalidContributionScore
        );
    });
}

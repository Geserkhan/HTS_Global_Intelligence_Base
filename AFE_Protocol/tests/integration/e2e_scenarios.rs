//! AFE Protocol E2E 통합 테스트 시나리오
//!
//! 시나리오 1: 정상 대출 플로우
//! 시나리오 3: 우수 사용자 혜택

#![cfg(test)]

mod integration_helpers;
use integration_helpers::*;

use frame_support::{assert_ok, assert_err};
use sp_runtime::FixedPointNumber;

/// ═══════════════════════════════════════════════════════════════════════════
/// 시나리오 1: 정상 대출 플로우
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 플로우:
/// 1. Oracle (Eyes) → BTC 가격 조회
/// 2. Brain → P_adj 계산 (변동성 및 유동성 고려)
/// 3. Shield → LTV 검증
/// 4. Heart → CS 기반 CR_dynamic 계산
/// 5. Heart → 대출 실행
/// 6. 블록 진행 → 담보율 모니터링
#[test]
fn scenario_1_normal_loan_flow() {
    new_test_ext().execute_with(|| {
        test_log!("═══════════════════════════════════════");
        test_log!("시나리오 1: 정상 대출 플로우");
        test_log!("═══════════════════════════════════════");

        // ─────────────────────────────────────────────────────────────────
        // Step 1: Oracle (Eyes) - BTC 가격 조회
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[Step 1] Oracle (Eyes) - 가격 조회");

        let btc_price = OracleGovernance::get_price(constants::BTC_ASSET_ID)
            .expect("BTC 가격을 조회할 수 없습니다");

        test_log!("  ✓ BTC 가격: ${}", btc_price.into_inner() / Price::DIV);
        assert_eq!(
            btc_price.into_inner(),
            constants::DEFAULT_BTC_PRICE,
            "초기 BTC 가격이 $50,000이어야 합니다"
        );

        // ─────────────────────────────────────────────────────────────────
        // Step 2: Brain - P_adj 계산 (변동성 및 유동성 고려)
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[Step 2] Brain - P_adj 계산");

        let volatility = 15; // 15% 변동성
        let liquidity_depth = 1_000_000_000_000_000_000_000_000; // 1M BTC

        let p_adj = calculate_p_adj(
            constants::BTC_ASSET_ID,
            volatility,
            liquidity_depth,
        ).expect("P_adj 계산 실패");

        test_log!("  • 변동성: {}%", volatility);
        test_log!("  • 유동성 깊이: {} BTC", liquidity_depth / Price::DIV);
        test_log!("  ✓ P_adj: ${}", p_adj.into_inner() / Price::DIV);

        // P_adj는 변동성을 고려하여 실제 가격보다 낮아야 함
        assert!(
            p_adj <= btc_price,
            "P_adj는 실제 가격보다 낮거나 같아야 합니다"
        );

        // ─────────────────────────────────────────────────────────────────
        // Step 3: Shield - LTV 검증
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[Step 3] Shield - LTV 검증");

        let collateral_amount = constants::DEFAULT_COLLATERAL; // 1 BTC
        let collateral_value = collateral_amount * p_adj.into_inner() / Price::DIV;

        // LTV 50%로 대출 (담보 가치의 50%)
        let loan_amount = collateral_value * 50 / 100;
        let max_ltv = 70; // 최대 LTV 70%

        test_log!("  • 담보: {} BTC", collateral_amount / Price::DIV);
        test_log!("  • 담보 가치: ${}", collateral_value / Price::DIV);
        test_log!("  • 대출 금액: ${}", loan_amount / Price::DIV);
        test_log!("  • 최대 LTV: {}%", max_ltv);

        let ltv_valid = verify_ltv(
            collateral_value,
            loan_amount,
            max_ltv,
        ).expect("LTV 검증 실패");

        assert!(ltv_valid, "LTV 검증이 통과되어야 합니다");
        test_log!("  ✓ LTV 검증 통과");

        // ─────────────────────────────────────────────────────────────────
        // Step 4: Heart - CS 기반 CR_dynamic 계산
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[Step 4] Heart - CR_dynamic 계산");

        let credit_score = constants::DEFAULT_CREDIT_SCORE; // CS = 50
        let cr_dynamic = calculate_cr_dynamic(credit_score);

        test_log!("  • Credit Score: {}", credit_score);
        test_log!("  ✓ CR_dynamic: {}%", cr_dynamic);
        assert_eq!(cr_dynamic, 80, "CS 50일 때 CR_dynamic은 80%여야 합니다");

        // ─────────────────────────────────────────────────────────────────
        // Step 5: Heart - 대출 실행
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[Step 5] Heart - 대출 실행");

        let loan_id = execute_loan(
            constants::BOB,
            constants::BTC_ASSET_ID,
            collateral_amount,
            loan_amount,
            credit_score,
        ).expect("대출 실행 실패");

        test_log!("  ✓ 대출 ID: {}", loan_id);
        test_log!("  ✓ 대출자: Bob ({})", constants::BOB);

        // 현재 담보율 확인
        let current_cr = calculate_collateral_ratio(collateral_value, loan_amount);
        test_log!("  • 현재 담보율: {}%", current_cr);

        // 담보율이 CR_dynamic보다 충분히 높아야 함
        assert_collateral_ratio_safe(current_cr, cr_dynamic, 20);

        // ─────────────────────────────────────────────────────────────────
        // Step 6: 블록 진행 - 담보율 모니터링
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[Step 6] 블록 진행 - 담보율 모니터링");

        // 100 블록 진행
        for block in 1..=100 {
            run_to_block(block);

            // 10블록마다 담보율 확인
            if block % 10 == 0 {
                let current_price = OracleGovernance::get_price(constants::BTC_ASSET_ID)
                    .expect("가격 조회 실패");
                let current_value = collateral_amount * current_price.into_inner() / Price::DIV;
                let current_cr = calculate_collateral_ratio(current_value, loan_amount);

                test_log!("  Block {}: CR = {}%", block, current_cr);

                // 담보율이 여전히 안전한지 확인
                assert!(
                    current_cr >= cr_dynamic,
                    "담보율이 CR_dynamic 이하로 떨어졌습니다"
                );
            }
        }

        test_log!("\n  ✓ 100블록 동안 담보율 안정적으로 유지");

        // ─────────────────────────────────────────────────────────────────
        // 최종 검증
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[최종 검증]");

        let final_price = OracleGovernance::get_price(constants::BTC_ASSET_ID)
            .expect("최종 가격 조회 실패");
        let final_value = collateral_amount * final_price.into_inner() / Price::DIV;
        let final_cr = calculate_collateral_ratio(final_value, loan_amount);

        test_log!("  • 최종 BTC 가격: ${}", final_price.into_inner() / Price::DIV);
        test_log!("  • 최종 담보 가치: ${}", final_value / Price::DIV);
        test_log!("  • 최종 담보율: {}%", final_cr);
        test_log!("  • CR_dynamic: {}%", cr_dynamic);

        assert!(final_cr >= cr_dynamic, "최종 담보율이 안전하지 않습니다");

        test_log!("\n✅ 시나리오 1 완료: 정상 대출 플로우 성공!");
    });
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 시나리오 3: 우수 사용자 혜택
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 검증 사항:
/// 1. CS = 90 사용자
/// 2. CR_dynamic = 60% (낮은 담보율)
/// 3. 높은 대출 한도 확인
/// 4. 낮은 담보율 이점
#[test]
fn scenario_3_excellent_user_benefits() {
    new_test_ext().execute_with(|| {
        test_log!("═══════════════════════════════════════");
        test_log!("시나리오 3: 우수 사용자 혜택");
        test_log!("═══════════════════════════════════════");

        // ─────────────────────────────────────────────────────────────────
        // 우수 사용자 (CS = 90) vs 일반 사용자 (CS = 50) 비교
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[사용자 비교]");

        let excellent_cs = constants::HIGH_CREDIT_SCORE; // CS = 90
        let normal_cs = constants::DEFAULT_CREDIT_SCORE; // CS = 50

        let excellent_cr = calculate_cr_dynamic(excellent_cs);
        let normal_cr = calculate_cr_dynamic(normal_cs);

        test_log!("  우수 사용자 (CS = {}):", excellent_cs);
        test_log!("    • CR_dynamic: {}%", excellent_cr);

        test_log!("  일반 사용자 (CS = {}):", normal_cs);
        test_log!("    • CR_dynamic: {}%", normal_cr);

        assert_eq!(excellent_cr, 60, "우수 사용자의 CR_dynamic은 60%여야 합니다");
        assert_eq!(normal_cr, 80, "일반 사용자의 CR_dynamic은 80%여야 합니다");

        // ─────────────────────────────────────────────────────────────────
        // 동일 담보로 대출 가능 금액 비교
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[대출 한도 비교] - 동일 담보: 1 BTC ($50,000)");

        let collateral_amount = constants::DEFAULT_COLLATERAL; // 1 BTC
        let btc_price = OracleGovernance::get_price(constants::BTC_ASSET_ID)
            .expect("가격 조회 실패");
        let collateral_value = collateral_amount * btc_price.into_inner() / Price::DIV;

        // 우수 사용자: CR_dynamic = 60%
        // 대출 가능 = 담보 가치 / CR_dynamic * 100
        let excellent_max_loan = collateral_value * 100 / excellent_cr as u128;

        // 일반 사용자: CR_dynamic = 80%
        let normal_max_loan = collateral_value * 100 / normal_cr as u128;

        test_log!("  담보 가치: ${}", collateral_value / Price::DIV);
        test_log!("  우수 사용자 최대 대출: ${}", excellent_max_loan / Price::DIV);
        test_log!("  일반 사용자 최대 대출: ${}", normal_max_loan / Price::DIV);

        let loan_difference = excellent_max_loan - normal_max_loan;
        let difference_percent = loan_difference * 100 / normal_max_loan;

        test_log!("  ✓ 대출 한도 차이: ${}", loan_difference / Price::DIV);
        test_log!("  ✓ 차이 비율: {}% 더 높음", difference_percent);

        // 우수 사용자가 더 많이 빌릴 수 있어야 함
        assert!(
            excellent_max_loan > normal_max_loan,
            "우수 사용자의 대출 한도가 더 높아야 합니다"
        );

        // ─────────────────────────────────────────────────────────────────
        // 우수 사용자 대출 실행
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[우수 사용자 대출 실행]");

        // 안전 마진을 고려하여 최대 대출의 90%만 빌림
        let loan_amount = excellent_max_loan * 90 / 100;

        test_log!("  • 대출 금액: ${}", loan_amount / Price::DIV);
        test_log!("  • 최대 대출의: 90%");

        let loan_id = execute_loan(
            constants::ALICE,
            constants::BTC_ASSET_ID,
            collateral_amount,
            loan_amount,
            excellent_cs,
        ).expect("우수 사용자 대출 실행 실패");

        test_log!("  ✓ 대출 ID: {}", loan_id);
        test_log!("  ✓ 대출자: Alice ({})", constants::ALICE);

        // 현재 담보율 확인
        let current_cr = calculate_collateral_ratio(collateral_value, loan_amount);
        test_log!("  • 현재 담보율: {}%", current_cr);

        // ─────────────────────────────────────────────────────────────────
        // 낮은 담보율 이점 검증
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[낮은 담보율 이점]");

        // 일반 사용자는 동일 금액을 빌리려면 더 많은 담보 필요
        let required_collateral_normal = loan_amount * normal_cr as u128 / 100;
        let required_collateral_excellent = loan_amount * excellent_cr as u128 / 100;

        let collateral_saved = required_collateral_normal - required_collateral_excellent;
        let saved_percent = collateral_saved * 100 / required_collateral_normal;

        test_log!("  동일 대출 금액 (${})을 받기 위해:", loan_amount / Price::DIV);
        test_log!("    일반 사용자 필요 담보: ${}", required_collateral_normal / Price::DIV);
        test_log!("    우수 사용자 필요 담보: ${}", required_collateral_excellent / Price::DIV);
        test_log!("    ✓ 절약된 담보: ${} ({}%)", collateral_saved / Price::DIV, saved_percent);

        // 우수 사용자는 담보를 절약할 수 있음
        assert!(
            required_collateral_excellent < required_collateral_normal,
            "우수 사용자는 더 적은 담보로 동일 금액을 빌릴 수 있어야 합니다"
        );

        // ─────────────────────────────────────────────────────────────────
        // 가격 하락 시나리오 - 우수 사용자의 여유
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[가격 하락 시나리오]");

        // BTC 가격 15% 하락
        let price_drop_percent = 15;
        let new_price = btc_price.into_inner() * (100 - price_drop_percent) / 100;

        test_log!("  • BTC 가격 {}% 하락", price_drop_percent);
        test_log!("  • 새 가격: ${}", new_price / Price::DIV);

        assert_ok!(update_btc_price(new_price));

        let new_collateral_value = collateral_amount * new_price / Price::DIV;
        let new_cr = calculate_collateral_ratio(new_collateral_value, loan_amount);

        test_log!("  • 새 담보 가치: ${}", new_collateral_value / Price::DIV);
        test_log!("  • 새 담보율: {}%", new_cr);
        test_log!("  • CR_dynamic: {}%", excellent_cr);

        // 우수 사용자는 15% 하락에도 안전
        assert!(
            new_cr > excellent_cr,
            "15% 하락 후에도 담보율이 CR_dynamic 이상이어야 합니다"
        );

        let safety_margin = new_cr - excellent_cr;
        test_log!("  ✓ 안전 마진: {}%", safety_margin);

        // 일반 사용자라면?
        test_log!("\n  [비교] 동일 조건에서 일반 사용자:");
        let normal_user_loan = collateral_value * 90 / 100; // 동일한 90% 대출
        let normal_max = collateral_value * 100 / normal_cr as u128;

        if normal_user_loan > normal_max {
            test_log!("    ✗ 일반 사용자는 이 금액을 빌릴 수 없음!");
        } else {
            let normal_new_cr = calculate_collateral_ratio(new_collateral_value, normal_user_loan);
            test_log!("    • 일반 사용자의 새 담보율: {}%", normal_new_cr);

            if normal_new_cr < normal_cr {
                test_log!("    ⚠ 일반 사용자는 청산 위험 구역 진입!");
            }
        }

        // ─────────────────────────────────────────────────────────────────
        // 최종 혜택 요약
        // ─────────────────────────────────────────────────────────────────
        test_log!("\n[우수 사용자 혜택 요약]");
        test_log!("  1. 낮은 CR_dynamic: 60% (vs 80%)");
        test_log!("  2. 높은 대출 한도: {}% 더 많이 빌림", difference_percent);
        test_log!("  3. 담보 효율성: {}% 담보 절약", saved_percent);
        test_log!("  4. 가격 변동 여유: {}% 안전 마진", safety_margin);

        test_log!("\n✅ 시나리오 3 완료: 우수 사용자 혜택 검증 성공!");
    });
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 추가 테스트: 여러 사용자의 동시 대출
/// ═══════════════════════════════════════════════════════════════════════════
#[test]
fn test_multiple_users_concurrent_loans() {
    new_test_ext().execute_with(|| {
        test_log!("═══════════════════════════════════════");
        test_log!("추가 테스트: 여러 사용자 동시 대출");
        test_log!("═══════════════════════════════════════\n");

        let users = vec![
            (constants::ALICE, constants::HIGH_CREDIT_SCORE, "Alice (우수)"),
            (constants::BOB, constants::DEFAULT_CREDIT_SCORE, "Bob (일반)"),
            (constants::CHARLIE, constants::LOW_CREDIT_SCORE, "Charlie (저신용)"),
        ];

        let collateral_amount = constants::DEFAULT_COLLATERAL; // 1 BTC
        let btc_price = OracleGovernance::get_price(constants::BTC_ASSET_ID)
            .expect("가격 조회 실패");
        let collateral_value = collateral_amount * btc_price.into_inner() / Price::DIV;

        for (user, credit_score, name) in users.iter() {
            test_log!("[{}] CS = {}", name, credit_score);

            let cr_dynamic = calculate_cr_dynamic(*credit_score);
            let max_loan = collateral_value * 100 / cr_dynamic as u128;
            let loan_amount = max_loan * 85 / 100; // 최대의 85%만 빌림

            test_log!("  • CR_dynamic: {}%", cr_dynamic);
            test_log!("  • 대출 금액: ${}", loan_amount / Price::DIV);

            let loan_id = execute_loan(
                *user,
                constants::BTC_ASSET_ID,
                collateral_amount,
                loan_amount,
                *credit_score,
            ).expect("대출 실행 실패");

            test_log!("  ✓ 대출 ID: {}\n", loan_id);
        }

        test_log!("✅ 3명의 사용자가 모두 성공적으로 대출 받음!");
    });
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 추가 테스트: LTV 한도 초과 시도
/// ═══════════════════════════════════════════════════════════════════════════
#[test]
fn test_ltv_limit_exceeded() {
    new_test_ext().execute_with(|| {
        test_log!("═══════════════════════════════════════");
        test_log!("추가 테스트: LTV 한도 초과");
        test_log!("═══════════════════════════════════════\n");

        let collateral_amount = constants::DEFAULT_COLLATERAL;
        let btc_price = OracleGovernance::get_price(constants::BTC_ASSET_ID)
            .expect("가격 조회 실패");
        let collateral_value = collateral_amount * btc_price.into_inner() / Price::DIV;

        // 과도한 대출 시도 (담보 가치의 90%, LTV 70% 초과)
        let excessive_loan = collateral_value * 90 / 100;
        let max_ltv = 70;

        test_log!("  • 담보 가치: ${}", collateral_value / Price::DIV);
        test_log!("  • 시도 대출: ${} (90%)", excessive_loan / Price::DIV);
        test_log!("  • 최대 LTV: {}%", max_ltv);

        let ltv_valid = verify_ltv(
            collateral_value,
            excessive_loan,
            max_ltv,
        ).expect("LTV 검증 실행 실패");

        assert!(!ltv_valid, "과도한 대출은 LTV 검증을 통과하지 못해야 합니다");

        test_log!("  ✓ LTV 검증 실패 (예상대로)");
        test_log!("\n✅ LTV 한도 초과 방지 성공!");
    });
}

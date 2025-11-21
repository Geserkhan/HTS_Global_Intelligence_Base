//! AFE Protocol E2E 통합 테스트 모듈
//!
//! 4대 Pallet (Brain, Eyes, Shield, Heart) 통합 테스트
//!
//! ## 테스트 구조
//! - `integration_helpers`: 공통 헬퍼 함수 및 유틸리티
//! - `e2e_scenarios`: 정상 플로우 및 우수 사용자 시나리오
//! - `great_crash_scenario`: 극단적 시장 붕괴 시나리오
//!
//! ## 실행 방법
//! ```bash
//! # 모든 통합 테스트 실행
//! cargo test --test integration
//!
//! # 특정 시나리오만 실행
//! cargo test --test integration scenario_1
//! cargo test --test integration scenario_2
//! cargo test --test integration scenario_3
//!
//! # 상세 로그 출력
//! cargo test --test integration -- --nocapture
//! ```

#![cfg(test)]

// 모듈 선언
mod integration_helpers;
mod e2e_scenarios;
mod great_crash_scenario;

// 공통 imports
pub use integration_helpers::*;

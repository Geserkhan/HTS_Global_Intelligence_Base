# ADGM Legal Core Index

이 폴더는 **ADGM(Abu Dhabi Global Market)** 관할 내 법적 구조, 준법 리포트, 라이선스 문서 및 자산 관리 시스템을 포함합니다.

## 🗂 핵심 문서 목록

### 📋 규제 및 컴플라이언스
| 파일명 | 설명 | 상태 |
|---------|------|------|
| `fsra_exec_summary_v2_2.md` | FSRA 제출용 요약 문서 | ✅ 완료 |
| `fsra_cover_letter_v2_2.md` | FSRA 신청 커버 레터 | ✅ 완료 |
| `fsra_blx_core_bp_v2_2.md` | BLX CORE 자산관리 사업계획서 (Cat 3C) | ✅ 완료 |
| `fsra_blx_trading_bp_v2_2.md` | BLX TRADING 거래 사업계획서 | ✅ 완료 |
| `blx-compliance-audit-2025.md` | 2025 컴플라이언스 감사 보고서 | ✅ 완료 |
| `blx-aml-ctf-policy-2025.md` | AML/CFT 정책 및 절차 | ✅ 완료 |

### 💼 재무 및 리스크 관리
| 파일명 | 설명 | 상태 |
|---------|------|------|
| `blx-consolidated-financials-v2.md` | 통합 재무제표 및 5개년 계획 (2026-2030) | ✅ 완료 |
| `blx-risk-framework-v2.md` | 통합 리스크 관리 프레임워크 | ✅ 완료 |
| `blx-esg-framework-2025.md` | ESG 프레임워크 및 사회적 영향 | ✅ 완료 |

### 🏦 포트폴리오 리밸런싱 시스템 (신규)
| 파일명 | 설명 | 상태 |
|---------|------|------|
| `portfolio-rebalancing-framework.md` | 자산배분 리밸런싱 전략 프레임워크 | 🔄 설계단계 |
| `rebalancing-parameters.yaml` | 리밸런싱 시스템 설정 파일 | 🔄 설계단계 |
| `rebalancing-smart-contracts.md` | 스마트 컨트랙트 기술 사양 | 🔄 설계단계 |

### 🏢 기타 사업 계획
| 파일명 | 설명 | 상태 |
|---------|------|------|
| `dmhb-dlt-foundation-bp.md` | DMHB DLT 재단 사업계획서 | ✅ 완료 |
| `blx-reward-korea-bp.md` | BLX REWARD (한국) 사업계획서 | ✅ 완료 |

## ⚖️ 핵심 포인트

### FSRA Category 3C - Managing Assets
- **BLX CORE**: USD 500M AUM 목표 (금 보유고, 부동산 펀드)
- **포트폴리오 리밸런싱**: $100M 자금 자동 리밸런싱 시스템
- **리스크 관리**: 다층 보험 체계, 컴플라이언스 프로토콜
- **제로 레버리지 정책**: 100% 자기자본 운용

### 자산 배분 전략 (Portfolio Rebalancing System)
- **Stablecoins (40%)**: USDC/USDT - 즉시 유동성
- **DeFi Yields (30%)**: Aave/Curve - 수익률 최적화
- **Real World Assets (20%)**: 미국 국채 - 저위험 수익
- **Reserve Assets (10%)**: ETH/BTC - 변동성 헤지

### 리밸런싱 트리거
- **드리프트 임계값**: 5% 편차 발생 시 자동 실행
- **승인 프로세스**: $5M 이상 거래는 DAO 멀티시그 승인 필요
- **실행 빈도**: 주간 검토, 필요 시 자동 실행
- **슬리피지 제한**: 최대 0.5% 허용

## 🤖 AI 탐색 순서

### 규제 이해를 위한 순서
1. `fsra_exec_summary_v2_2.md` - 전체 개요 파악
2. `fsra_blx_core_bp_v2_2.md` - 자산관리 라이선스 범위
3. `blx-risk-framework-v2.md` - 리스크 관리 체계

### 재무 및 자산 관리를 위한 순서
1. `blx-consolidated-financials-v2.md` - 재무 계획 및 프로젝션
2. `portfolio-rebalancing-framework.md` - 포트폴리오 전략
3. `rebalancing-parameters.yaml` - 시스템 설정값
4. `rebalancing-smart-contracts.md` - 기술 구현 사양

### 컴플라이언스 검토를 위한 순서
1. `blx-compliance-audit-2025.md` - 감사 절차
2. `blx-aml-ctf-policy-2025.md` - 자금세탁방지 정책
3. `blx-esg-framework-2025.md` - ESG 기준

## 📊 시스템 통합 포인트

**Portfolio Rebalancing System ↔ Existing Infrastructure:**
- **BLX CORE**: 금 보유고 최적화 및 부동산 배분
- **TRR Pool**: DeFi 수익률을 TRR-X 결제 레이어에 연결
- **BLXWT Token**: ETH/BTC 리저브를 보조 담보로 활용
- **DMHB DLT**: ADGM ↔ Labuan 간 스테이블코인 정산
- **DAO Governance**: 배분 비율 변경은 DAO 투표로 결정

## 🔗 관련 문서

- **TRR 시스템**: `/01_HTS_DAO_TRR_MASTER/P3_DAO_TRR_Pool_Patent_Spec.md.md`
- **BLXWT 토큰**: `/01_HTS_DAO_TRR_MASTER/P2_BLXWT_NonRedeemable_Token_Patent_Spec.md.md`
- **Labuan 은행**: `/03_LABUAN_DMH_BANK/`
- **AI 통합**: `/Meta_Bridge_AI_Integration/`

## 📅 업데이트 이력

- **2025-11-18**: Portfolio Rebalancing System 설계 문서 추가
- **2025-XX-XX**: FSRA v2.2 문서 업데이트
- **2025-XX-XX**: 통합 리스크 프레임워크 v2 작성



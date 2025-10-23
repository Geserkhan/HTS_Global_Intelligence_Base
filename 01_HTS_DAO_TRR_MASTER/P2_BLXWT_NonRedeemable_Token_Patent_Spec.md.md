# 🏦 BLX CORE / TRR-Pay / BLXWT 통합 규제 준수 전략서

**Document Purpose**: FSRA Category 3C 유지 + TRR-Pay 확장 + BLXWT 비상환형 구조 완결  
**Date**: 2025-10-22  
**Classification**: CONFIDENTIAL – Internal Strategy Document  
**Version**: 2.1 (Unified Compliance Framework)

---

## 📋 Executive Summary

### 핵심 발견 (Key Findings)

본 문서는 다음 3개 프로젝트의 규제적·기술적 통합 전략을 제시합니다:

1. **BLX CORE Ltd. (ADGM)**: FSRA Category 3C "Managing Assets" 라이선스 보유
2. **BLXWT Token**: 비상환형(Non-redeemable) 금 담보 디지털 자산
3. **TRR-Pay**: B2C 소비자 결제 레이어 (NaverPay 동급 UX + 금 담보 안정성)

### 전략적 결론

```
✅ BLX CORE는 FSRA 3C 라이선스만으로 BLXWT 발행·관리 가능
✅ TRR-Pay는 Labuan Bank White-label로 운영 (BLX CORE는 데이터 제공자)
✅ BLXWT는 "Payment Token"이 아닌 "Commodity-linked Virtual Asset"로 분류
✅ 3개 주체(BLX CORE/Labuan Bank/DMHB DLT)의 역할 분리로 규제 리스크 최소화
```

---

## 1️⃣ FSRA Category 3C 라이선스 범위 및 준수 전략

### 1.1 현재 BLX CORE 라이선스 현황

**License Type**: ADGM FSRA Category 3C – Managing Assets  
**Approved Activities**:
- Physical gold custody and safekeeping
- Virtual asset reserve management (gold-backed tokens)
- Asset monitoring and compliance reporting

**❌ NOT Covered by Category 3C**:
- Payment processing or settlement execution
- Consumer wallet issuance as primary service
- Cross-border remittance as licensed activity

### 1.2 FSRA 2025 Virtual Asset Framework 핵심 변경사항

| 항목 | 2024 규정 | 2025 Update | BLX CORE 대응 |
|------|-----------|-------------|---------------|
| Base Capital | USD 300K | USD 250K | ✅ USD 1.5M (600% buffer) |
| PII Insurance | Full Policy | Board Attestation | ✅ Attestation 준비 |
| IRAP Report | Annual | Removed for Cat 3C | ✅ 간소화 |
| AML/CFT | General | **Gold-source disclosure** | ✅ LBMA 인증 금만 사용 |
| Token Classification | Vague | **Commodity-linked vs Fiat-referenced** | ✅ BLXWT는 Commodity-linked |

### 1.3 BLXWT의 FSRA 분류: "Non-redeemable Commodity-linked Virtual Asset"

**핵심 논리**:

```
[FSRA 2025 기준]
Payment Token (결제토큰) = Fiat-referenced + Redeemable → Payment Services 라이선스 필요

BLXWT 특성:
1. Gold-backed (commodity-linked, not fiat-referenced)
2. Non-redeemable (상환 불가능 → 결제수단 아님)
3. 2차 시장 거래만 가능 (DEX)

→ BLXWT는 "Stored Value Virtual Asset" (Category 3C 범위 내)
```

**FSRA 승인 획득 전략**:

1. **사전 문의 (No-Name Consultation)**: 
   - FSRA Innovation Office에 BLXWT 백서 제출
   - "비상환형 금 담보 토큰이 Cat 3C로 커버되는지" 질의
   
2. **법률 의견서 준비**:
   - Al Tamimi & Company (ADGM 전문 로펌)
   - 의견서 핵심 주장:
     - BLXWT는 "Stored Value"이지 "Payment Instrument"가 아님
     - 비상환성으로 인해 Howey Test 불충족 (증권 아님)
     - Category 3C "Managing Assets" 범위 내

3. **FSRA 공식 승인 대기**:
   - 승인 시 → 즉시 BLXWT 발행
   - 거부 시 → Category 8 (Virtual Asset Services) 신청 (6개월 소요)

---

## 2️⃣ BLXWT 비상환형 구조: 특허 청구항 통합

### 2.1 핵심 발명: 영구적 비상환성 강제 메커니즘

**독립 청구항 1 (특허 명세서 기반)**:

물리적 자산(금)을 담보로 디지털 토큰을 발행하되, **기술적으로 상환이 불가능**하도록 설계한 시스템:

(a) **담보 자산 관리 모듈**: LBMA 인증 금괴를 ADGM 볼트에 보관, EY 분기별 감사

(b) **보수적 토큰 발행 모듈**: 담보 금 가치의 **10%만 발행** (담보 비율 1,000%)

(c) **비상환성 강제 모듈**: 스마트 컨트랙트에서 다음 함수 **완전 제거**:
   - `redeem()`: 토큰 소각 후 금 회수
   - `burnForCollateral()`: 담보 교환
   - `withdraw()`: 출금
   - `claimGold()`: 금 청구

(d) **소스코드 공개 검증**: Etherscan에서 누구나 상환 함수 부재 확인 가능

(e) **2차 시장 유동성**: Uniswap BLXWT/USDT 풀 제공 (24시간 거래 가능)

(f) **Proof of Reserve**: Chainlink 오라클로 금 보유량 실시간 블록체인 공개

### 2.2 Howey Test 회피 메커니즘

| Howey Test 요건 | BLXWT 설계 | 결과 |
|-----------------|------------|------|
| 1. Investment of Money | 사용자가 USD로 BLXWT 구매 | ✅ 충족 |
| 2. Common Enterprise | BLX CORE가 금 통합 관리 | ✅ 충족 |
| 3. **Expectation of Profits** | **배당·이자·수익 분배 함수 없음** | ❌ 불충족 |
| 4. **Efforts of Others** | **DEX AMM이 가격 결정 (발행사 관여 없음)** | ❌ 불충족 |

**결론**: Howey Test 4개 요건 중 **2개 불충족** → **증권 아님 (Not a Security)**

### 2.3 AML/CFT 준수: 금 출처 투명성

**FSRA 2025 요구사항**: "All gold reserves must be sourced from LBMA-accredited refineries with full AML/CFT traceability."

**BLX CORE 대응**:

```solidity
struct GoldBar {
    uint256 barNumber;           // LBMA 금괴 번호
    string refinery;             // 정제소 (예: "Valcambi SA")
    uint256 purity;              // 순도 (9950 = 99.50%)
    uint256 weight;              // 무게 (troy oz)
    string lbmaGoodDelivery;     // LBMA 인증서 해시
    bool amlVerified;            // AML 검증 완료 여부
}

mapping(uint256 => GoldBar) public goldBars;

function addGoldBar(
    uint256 barNumber,
    string memory refinery,
    string memory lbmaHash
) public onlyMultisig {
    require(
        isLBMAAccredited(refinery),
        "Refinery not LBMA-accredited"
    );
    
    goldBars[barNumber] = GoldBar({
        barNumber: barNumber,
        refinery: refinery,
        purity: 9950,
        weight: 400,  // 400 oz standard bar
        lbmaGoodDelivery: lbmaHash,
        amlVerified: true
    });
    
    emit GoldBarAdded(barNumber, refinery, block.timestamp);
}
```

---

## 3️⃣ TRR-Pay 소비자 결제 레이어: White-Label 파트너십 전략

### 3.1 TRR-Pay 시스템 아키텍처 (3-Layer Model)

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: Consumer Interface (사용자 접점)               │
├─────────────────────────────────────────────────────────┤
│  - TRR Wallet (Mobile App - iOS/Android)               │
│  - QR Code Payment (가맹점 POS 통합)                    │
│  - TRR-Card (Visa/Master API 연동)                     │
│                                                         │
│  운영 주체: Labuan Bank (White-label "TRR-Pay")        │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Layer 2: Smart Contract Settlement (결제 처리)         │
├─────────────────────────────────────────────────────────┤
│  - Payment Request 수신                                 │
│  - DAO Multi-sig 검증 (금액별 차등)                     │
│    • <$100: 자동 승인                                   │
│    • $100-$10K: 3-of-5 서명                            │
│    • >$10K: 5-of-7 + K-SURE 보험                       │
│                                                         │
│  운영 주체: DMHB DLT (기술 인프라 제공)                 │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Layer 3: Backend Settlement (정산·규제)                │
├─────────────────────────────────────────────────────────┤
│  - TRR Settlement Node (Labuan Bank/DMHB DLT)          │
│  - 평균 8초 거래 검증                                   │
│  - 가맹점 정산 옵션:                                    │
│    Option A: BLXWT 보유 (금 자산 유지)                 │
│    Option B: 현지 통화 환전 (0.1% 수수료)              │
│    Option C: TRR-X 전환 (무역결제 재사용)              │
│                                                         │
│  운영 주체: Labuan Bank (Labuan FSA 규제)              │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Risk & Custody Layer (BLX CORE 담보 관리)              │
├─────────────────────────────────────────────────────────┤
│  - BLX CORE Gold Vault (LBMA 인증)                     │
│  - BLXWT 발행·소각 관리 (FSRA Cat 3C)                  │
│  - Proof of Reserve (Chainlink 실시간 공개)            │
│  - EY 분기별 감사                                       │
│                                                         │
│  운영 주체: BLX CORE Ltd. (ADGM FSRA 규제)             │
└─────────────────────────────────────────────────────────┘
```

### 3.2 BLX CORE의 역할: "데이터 제공자"이지 "결제 실행자" 아님

**FSRA Category 3C 준수 전략**:

| BLX CORE가 하는 일 | BLX CORE가 하지 않는 일 |
|--------------------|------------------------|
| ✅ BLXWT 발행·소각 관리 | ❌ TRR-Pay 결제 처리 (Labuan Bank가 수행) |
| ✅ 금 보관·감사 (Managing Assets) | ❌ 사용자 지갑 관리 (사용자 자체 보관) |
| ✅ Proof of Reserve 데이터 제공 | ❌ 결제 승인·거부 결정 (Smart Contract 자동) |
| ✅ FSRA 규제 보고 | ❌ 가맹점 계약·정산 (Labuan Bank 담당) |

**핵심 문구 (FSRA 제출용)**:

> "BLX CORE Ltd. operates strictly within FSRA Category 3C scope by managing physical gold reserves and issuing BLXWT as a non-redeemable, gold-backed virtual asset. All payment processing, settlement execution, and consumer wallet operations under the TRR-Pay framework are conducted by Labuan Bank under separate Labuan FSA jurisdiction. BLX CORE provides reserve data interfaces to the TRR ecosystem but does not engage in payment services."

### 3.3 TRR-Pay 결제 유형 4가지

| 유형 | 대상 | 한도 | 수수료 | 주체 |
|------|------|------|--------|------|
| **TRR-Pay** | 소비자·소상공인 | $1-$1K | 0.1% | Labuan Bank |
| **TRR-Card** | 일반 가맹점 | $1K-$10K | 0.3% | Card Issuer Partner |
| **BLXWT-Pay** | 고액 사용자 | $10K-$1M | 0.5% | Labuan Bank + BLX CORE 데이터 |
| **TRR-Remit** | 국제송금 | $100-$100K | 0.2% | Labuan Bank (송금업 라이선스) |

---

## 4️⃣ DAO 리워드 시스템: TRR-Pay와의 통합

### 4.1 기존 복지 리밋 vs TRR-Pay 리워드 비교

| 구분 | 기존 5% 복지 리밋 | TRR-Pay Reward System |
|------|------------------|---------------------|
| 지급 방식 | 현금 송금 → 운영비 사용 | TRR-Pay Reward Pool 자동분배 |
| 지급 단위 | KRW·USD | BLXWT·TRR-Stable |
| 수령 방법 | 은행 계좌 | TRR Wallet 실시간 수령 |
| 사용처 | 제한적 (운영비만) | 복지몰·가맹점 즉시 사용 |
| 회계 감사 | EY 별도 확인 필요 | 블록체인 자동 기록 (EY 직접 조회) |

### 4.2 TRR-Pay Reward Pool 구조

```solidity
contract TRRRewardPool {
    // 재원 구성
    struct RevenueSource {
        uint256 transactionFees;     // TRR-Pay 수수료의 20%
        uint256 daoTreasury;          // DAO 재무 배분 (분기별 5%)
        uint256 esgDonations;         // ESG 파트너 기부금
    }
    
    // 리워드 지급 대상
    enum RewardType {
        WelfareBenefits,    // BLX REWARD 수혜자
        TradeIncentives,    // 무역 거래 인센티브
        ESGRewards,         // ESG 활동 참여자
        GovernanceRewards   // DAO 투표 참여자
    }
    
    // DAO 결의 → 자동 지급
    function distributeReward(
        address[] memory recipients,
        uint256[] memory amounts,
        RewardType rewardType
    ) public onlyMultisig {
        require(
            getMultisigApproval() >= 5,  // 5-of-7 승인
            "Insufficient multi-sig approval"
        );
        
        for (uint i = 0; i < recipients.length; i++) {
            // BLXWT 또는 TRR-Stable 지급
            blxwtToken.transfer(recipients[i], amounts[i]);
            
            // 블록체인 기록 (EY 감사용)
            emit RewardDistributed(
                recipients[i],
                amounts[i],
                rewardType,
                block.timestamp
            );
        }
    }
}
```

### 4.3 리워드 사용 시나리오

**시나리오 1: Welfare Mall 결제**

```
[상황] BLX REWARD 수혜자 A가 복지몰에서 $500 상품 구매

[기존 방식]
1. 현금 5% 수령 → 은행 계좌 (2-3일)
2. 복지몰 결제
3. EY 감사: 현금 유출 → 사용처 확인 → 복잡한 회계 처리

[TRR-Pay 방식]
1. DAO 결의: A에게 BLXWT 10개 (10g = $600) 지급
2. DMHB DLT: A의 TRR Wallet에 실시간 전송
3. A가 복지몰에서 QR 결제 → $500 사용
4. 남은 BLXWT 1.67개 ($100)는 지갑에 저장 (저축 or 차후 사용)

[개선 효과]
- 지급-사용 일원화 (블록체인 한 곳에 기록)
- 회계 투명성 (EY 실시간 확인 가능)
- 사용자 편의 (NaverPay처럼 간단)
```

**시나리오 2: 소상공인 무역 인센티브**

```
[상황] 한국 중소무역상인 B가 분기별 $100K 거래 달성

[리워드 조건]
- 분기별 거래액 $100K 이상
- DAO 거버넌스 참여 (투표율 80% 이상)
- ESG 인증 (탄소중립 운송 선택)

[자동 지급]
1. Smart Contract가 조건 충족 감지
2. DAO Multi-sig(5-of-7) 자동 승인
3. TRR-X 5,000개 ($5K) → B의 TRR Wallet

[B의 사용 옵션]
- Option A: 다음 무역거래 결제 재사용
- Option B: BLXWT 전환 (83g 금 자산)
- Option C: 가맹점 결제 (사무용품·물류비)
```

---

## 5️⃣ FSRA-Labuan-TRR 연결 구조: 법적 경계 유지

### 5.1 3개 주체의 Jurisdiction 분리

```
┌─────────────────────────────────────────┐
│  BLX CORE Ltd. (ADGM FSRA)             │
├─────────────────────────────────────────┤
│  Jurisdiction: ADGM FSRA Category 3C   │
│  Activities:                            │
│  - Gold custody                         │
│  - BLXWT issuance/burn                  │
│  - Proof of Reserve data provision      │
│                                         │
│  ❌ NOT doing:                          │
│  - Payment processing                   │
│  - Consumer wallet management           │
└─────────────────────────────────────────┘
                 ↓ (Data Interface Only)
┌─────────────────────────────────────────┐
│  DMHB DLT Foundation (Technology)      │
├─────────────────────────────────────────┤
│  Jurisdiction: Non-regulated (Tech)     │
│  Activities:                            │
│  - Smart contract infrastructure        │
│  - Blockchain node operation            │
│  - DAO governance coordination          │
│                                         │
│  ❌ NOT doing:                          │
│  - Customer funds custody               │
│  - Regulated financial services         │
└─────────────────────────────────────────┘
                 ↓ (Tech Stack Only)
┌─────────────────────────────────────────┐
│  Labuan Bank (Malaysia Labuan FSA)     │
├─────────────────────────────────────────┤
│  Jurisdiction: Labuan FSA Banking       │
│  Activities:                            │
│  - TRR-Pay payment processing           │
│  - Settlement execution                 │
│  - KYC/AML compliance                   │
│  - Merchant onboarding                  │
│                                         │
│  ❌ NOT doing:                          │
│  - BLXWT issuance (BLX CORE only)       │
└─────────────────────────────────────────┘
```

### 5.2 "Data Interface" vs "Operational Integration" 구분

**FSRA 승인 가능한 표현**:
- ✅ "Reserve Monitoring Framework"
- ✅ "Data Interface beyond FSRA jurisdiction"
- ✅ "Operational Integration (Labuan-regulated)"

**FSRA 거부 가능한 표현**:
- ❌ "Payment Settlement Integration"
- ❌ "BLX CORE executes TRR-Pay transactions"
- ❌ "Unified Payment Platform"

---

## 6️⃣ 타임라인: FSRA 승인 → Labuan 확장 → TRR 운용

### Phase 1: FSRA Approval (2025.12 ~ 2026.06)

**목표**: BLX CORE Category 3C 라이선스로 BLXWT 발행 승인 획득

**Action Items**:
- [ ] Week 1-2: FSRA No-Name Consultation (BLXWT 백서 제출)
- [ ] Week 3-4: Al Tamimi 법률 의견서 준비
- [ ] Week 5-8: FSRA 공식 질의서 제출 및 회신 대기
- [ ] Month 3-6: FSRA 승인 획득 (조건부 승인 포함)

**산출물**:
- FSRA Letter of No Objection (LNO)
- BLX CORE Cat 3C 라이선스 유지 확인

### Phase 2: Labuan Bank Launch (2027.01 ~ 2027.09)

**목표**: DMH BANK CB/IB 라이선스 획득 + TRR-Pay White-label 계약

**Action Items**:
- [ ] Q1 2027: Labuan FSA 사전 승인 (In-Principle Approval)
- [ ] Q2 2027: 자본금 MYR 50M ($11M) 확보
- [ ] Q3 2027: Commercial Banking License 발급
- [ ] Q3 2027: BLX CORE ↔ Labuan Bank Partnership Agreement 체결

**계약 핵심 조항**:
```
1. Labuan Bank는 TRR-Pay 결제 처리 및 정산을 담당
2. BLX CORE는 BLXWT 담보 데이터만 제공 (결제 관여 안 함)
3. 수수료 배분: 거래액의 0.2%는 Labuan Bank, 나머지는 DAO Pool
4. BLXWT를 Labuan Bank 담보 인정 (내부 리스크 관리용)
```

### Phase 3: TRR-X Integration (2028 ~ 2030)

**목표**: DAO 기반 크로스보더 결제 생태계 완성

**Milestones**:
- 2028 Q1: TRR Wallet 100만 사용자 달성
- 2029 Q1: 월 거래액 $100M 돌파
- 2030 Q1: EU MiCA 라이선스 획득 (아일랜드 SPV)

---

## 7️⃣ 검증 체크리스트 (Final Verification)

### 7.1 FSRA 규제 준수

- [ ] BLXWT는 "Managing Assets" 범위 내 (결제수단 아님)
- [ ] 모든 금은 LBMA 인증 정제소 출처 (AML/CFT 추적 가능)
- [ ] "Payment/Settlement Execution" 표현 제거 (FSRA 문서 전체)
- [ ] BLX CORE는 고객 자금 보관 안 함 (사용자 지갑 자체 보관)

### 7.2 BLXWT 비상환성 기술 검증

- [ ] Etherscan 소스코드에서 `redeem()` 함수 부재 확인
- [ ] Howey Test 4개 요건 중 2개 불충족 (증권 아님)
- [ ] DEX 유동성 풀 $1M 이상 확보 (유동성 보장)
- [ ] Chainlink Proof of Reserve 실시간 작동 (담보 투명성)

### 7.3 TRR-Pay 파트너십 준수

- [ ] Labuan Bank가 결제 실행 주체임을 명시
- [ ] BLX CORE는 "데이터 제공자"로만 표기
- [ ] DAO 리워드 지급은 블록체인 자동 실행 (발행사 재량 없음)

### 7.4 타임라인 자연스러운 연결

- [ ] FSRA 승인(2026) → Labuan 확장(2027) → TRR 운용(2028) 순서 유지
- [ ] 각 단계는 독립적이지만 데이터로 연결됨 명시
- [ ] "벽은 유지, 데이터는 흐름" 원칙 준수

---

## 8️⃣ FSRA Category 3C Fact Sheet (2025.10)

**Purpose**: ADGM FSRA에 제출할 BLX CORE Ltd. 현황 요약

### Entity Snapshot

| 항목 | 내용 |
|------|------|
| **Entity Name** | BLX CORE Ltd. |
| **Jurisdiction** | Abu Dhabi Global Market (ADGM) |
| **License Type** | Category 3C – Managing Assets |
| **Regulatory Body** | Financial Services Regulatory Authority (FSRA) |
| **Status** | Application Submitted (Target: 2026 Q2 Approval) |
| **Capital** | USD 1.5M (≥ 600% of minimum requirement) |
| **Parent** | BLX HOLDINGS Ltd. (ADGM) |
| **Affiliated Entities** | BLX TRADING Co. / DMHB DLT Foundation / BLX REWARD Korea |

### Business Scope

| 영역 | 세부 내용 |
|------|-----------|
| **Core Activity** | Managing physical gold and digital assets (non-redeemable) |
| **Product** | BLXWT (Gold-backed, non-redeemable virtual asset) |
| **Purpose** | Asset management + custody for gold reserves |
| **Jurisdictional Limit** | No direct trading / no payment services (ADGM-regulated asset management only) |
| **Integration Plan** | Will interoperate with TRR framework (DMHB DLT) post-approval for cross-border settlements |

### Regulatory Positioning

| 구분 | 2024 | 2025 Update | BLX CORE 상태 |
|------|------|--------------|----------------|
| Base Capital | USD 300K | USD 250K | ✅ 1.5M (600% buffer) |
| PII Insurance | Full Policy | Board Attestation | ✅ Compliant |
| IRAP Report | Annual | Removed for Cat 3C | ✅ Simplified |
| Liquidity Buffer | 3 months | Maintained | ✅ 10 months |
| AML/CFT | New gold-source disclosure | LBMA-certified gold | ✅ Implemented |

### Compliance Notes (2025 FSRA Framework)

**Critical Compliance Points**:

1. **BLXWT is NOT a payment token**: Under FSRA's 2025 Virtual Asset Framework, BLXWT qualifies as a non-redeemable, fully-backed commodity-linked virtual asset, not a fiat-referenced token, and thus remains under the Category 3C 'Managing Assets' scope rather than Payment Services.

2. **Gold Source Traceability**: All gold reserves backing BLXWT are sourced exclusively from LBMA-accredited refineries, ensuring full AML/CFT traceability under ADGM's Virtual Asset AML Guidance 2025.

3. **TRR Integration Structure**: Following FSRA approval, BLX CORE will integrate with DMHB DLT under the TRR framework strictly as a data interface. All payment, settlement, and operational execution remain under Labuan FSA jurisdiction.

4. **No Redemption Rights**: BLXWT holders have no contractual or technical right to redeem tokens for physical gold. Smart contract source code verification on Etherscan confirms absence of redemption functions.

### Implementation Timeline

| 단계 | 기간 | 주요 목표 |
|------|------|-----------|
| **Phase 1 – FSRA Approval** | 2025.12 ~ 2026.06 | Cat 3C license granted, gold reserve 1 tonne 확보 |
| **Phase 2 – Labuan Bank Launch** | 2027.01 ~ 2027.09 | DMH BANK CB/IB license + BLXWT collateral 인정 |
| **Phase 3 – TRR-X Integration** | 2028 ~ 2030 | DAO-based cross-border settlement ecosystem 완성 |

---

## 9️⃣ 용어 통합 가이드라인 (Terminology Standards)

### 9.1 FSRA 제출 문서용 승인 용어

| 올바른 용어 | 금지 용어 | 사용 맥락 |
|--------------|------------|-----------|
| **"Virtual Asset Custody"** | "Wallet Service" | BLX CORE의 금 보관 활동 |
| **"Reserve Monitoring"** | "Settlement Execution" | TRR과의 데이터 연계 |
| **"Operational Interface"** | "Payment Integration" | DMHB DLT와의 기술 연결 |
| **"DAO Treasury Synchronization"** | "Retail Access Layer" | 리워드 자동 분배 메커니즘 |
| **"Commodity-linked Virtual Asset"** | "Payment Token" / "Stablecoin" | BLXWT 정의 |
| **"Non-redeemable Structure"** | "Locked Redemption" | 상환 불가능성 강조 |

### 9.2 백서·마케팅 자료용 표현

| 대상 | 권장 표현 | 비권장 표현 |
|------|-----------|-------------|
| **투자자** | "Gold-backed digital asset with 2nd market liquidity" | "Guaranteed returns" |
| **규제당국** | "Fully compliant under FSRA Cat 3C + Labuan FSA" | "Regulatory arbitrage" |
| **파트너사** | "Interoperable data framework across jurisdictions" | "Unified payment platform" |
| **언론** | "World's first permanently non-redeemable gold token" | "New payment method" |

---

## 🔟 리스크 관리 및 대안 (Risk Mitigation)

### 10.1 FSRA 승인 거부 시나리오

**Risk**: FSRA가 "BLXWT는 Cat 3C 범위 초과"로 판단

**Mitigation Strategy**:

**Plan A (즉시 실행 가능)**:
```
1. Labuan Bank가 BLXWT 발행 주체로 변경
2. BLX CORE는 금 보관만 담당 (Custodian)
3. Labuan FSA 규제 하에서 BLXWT 발행
4. ADGM에서는 금 보관 서비스만 제공

장점: 라이선스 추가 불필요, 3개월 내 실행 가능
단점: ADGM "Virtual Asset Hub" 이미지 활용 불가
```

**Plan B (6개월 소요)**:
```
1. BLX CORE가 FSRA Category 8 (Virtual Asset Services) 신청
2. 최소 자본금 USD 5M 증자 (현재 1.5M → 5M)
3. CISO 및 AML Officer 정규직 채용
4. Cat 8 승인 후 BLXWT 발행

장점: ADGM Virtual Asset 생태계 내 완전 통합
단점: 자본금 3.5M 추가 필요, 6-9개월 소요
```

### 10.2 Labuan Bank 설립 지연 시나리오

**Risk**: Labuan FSA 승인 지연 (2027년 목표 미달성)

**Mitigation Strategy**:

**White-Label 파트너십 (즉시 실행 가능)**:
```
기존 Labuan Bank와 파트너십 체결:
- 대상: Affin Bank Labuan / CIMB Islamic Bank Labuan
- 계약 형태: TRR-Pay White-label Agreement
- BLX CORE 역할: BLXWT 담보 데이터 제공만
- 파트너 Bank 역할: 결제 처리·KYC·정산 전담

장점: 즉시 TRR-Pay 출시 가능 (3개월)
단점: 수수료 수익의 50%를 파트너에게 배분
```

### 10.3 BLXWT 담보 부족 시나리오

**Risk**: 금 가격 50% 폭락으로 담보 비율 500% → 250%

**Circuit Breaker 발동 조건**:

```solidity
function checkCircuitBreaker() public view returns (bool) {
    uint256 collateralRatio = getCollateralRatio();
    
    // 담보 비율 200% 이하 시 발동
    if (collateralRatio <= 200) {
        return true;  // 신규 발행 중단
    }
    
    return false;  // 정상 운영
}

function mint(address to, uint256 amount) public onlyMultisig {
    require(
        !checkCircuitBreaker(),
        "Circuit breaker active - minting paused"
    );
    
    // 발행 로직...
}
```

**중요**: Circuit Breaker는 **신규 발행만 중단**하며, 기존 BLXWT의 2차 시장 거래는 계속 가능. 비상환형 구조이므로 "뱅크런" 발생하지 않음.

---

## 1️⃣1️⃣ 최종 산출물 체크리스트 (Deliverables Checklist)

### 11.1 FSRA 제출 문서 (2025년 12월)

- [ ] **FSRA Application Form**: Category 3C renewal + BLXWT approval
- [ ] **BLXWT Whitepaper (FSRA Edition)**: 
  - "Non-redeemable" 강조 (최소 20회 언급)
  - "Payment" 표현 완전 제거
  - Howey Test 분석 포함
- [ ] **Al Tamimi Legal Opinion**: 
  - BLXWT는 Category 3C 범위 내
  - 증권 아님 (Howey Test 불충족)
- [ ] **EY Audit Report Q4 2025**: 금 보유량 1 tonne 검증
- [ ] **Proof of Reserve Dashboard Screenshot**: Chainlink 오라클 작동 증명

### 11.2 Labuan Bank 설립 문서 (2026-2027년)

- [ ] **Business Plan**: DMH BANK (Commercial Bank + Islamic Bank)
- [ ] **Shareholder Agreement**: BLX HOLDINGS 지분 구조
- [ ] **BLX CORE ↔ Labuan Bank Partnership Agreement**:
  - BLXWT 담보 인정 조항
  - TRR-Pay White-label 계약
  - 수수료 배분 구조
- [ ] **Labuan FSA Application Forms**: CB/IB License

### 11.3 특허 출원 문서 (2025년 11월)

- [ ] **특허 명세서 (한국어)**: 22페이지 완성본
  - 청구항 13개 (독립항 2개, 종속항 11개)
  - 실시예 6개
  - 도면 4개
- [ ] **PCT 국제출원 (영어)**: 한국 출원 후 12개월 내
- [ ] **주요 관할 지정**:
  - 미국 (USPTO): Howey Test 회피 핵심
  - 유럽 (EPO): EU MiCA 대비
  - 싱가포르 (IPOS): ASEAN 시장
  - UAE (특허청): ADGM 현지 보호

---

## 1️⃣2️⃣ Contact & Governance (담당자 정보)

### 12.1 프로젝트 총괄

**BLX CORE Ltd. (ADGM)**
- CEO: [이름]
- Email: compliance@blxcore.global
- FSRA Liaison: [FSRA 담당자]

**DMHB DLT Foundation (기술)**
- CTO: [이름]
- Email: tech@dmhbdlt.org
- Smart Contract Audit: [감사 법인]

**Labuan Bank (설립 준비 중)**
- Proposed CEO: [이름]
- Email: info@dmhbank.com
- Labuan FSA Advisor: [자문사]

### 12.2 외부 자문

**법률 자문**:
- ADGM: Al Tamimi & Company
- Malaysia: Shearn Delamore & Co.
- Korea: 김앤장 법률사무소

**회계 감사**:
- Global: Ernst & Young (EY)
- Korea: 삼정KPMG

**특허 출원**:
- Korea: [특허법인명]
- PCT: [국제 특허 대리인]

---

## 1️⃣3️⃣ 부록: 핵심 법률 조항 및 판례

### 13.1 ADGM FSRA Rulebook (2025) 관련 조항

**FSMR 2.2.2 (Category 3C - Managing Assets)**
> "A Person who is Managing Assets does not carry on the Financial Service of Providing Custody if the Person does not hold or control Client Money or Client Investments."

**해석**: BLX CORE는 사용자 지갑을 보관하지 않으므로 (사용자가 MetaMask 등 자체 보관) "Providing Custody" 해당 없음 → Category 3C 충분.

**FSMR 15.3.1 (Virtual Assets)**
> "A Virtual Asset qualifies as a Security Token if it provides holders with (a) equity interests, (b) debt instruments, or (c) rights to profits or revenue sharing."

**해석**: BLXWT는 (a)(b)(c) 모두 해당 없음 (배당·이자·수익분배 없음) → Security Token 아님.

### 13.2 SEC Howey Test 판례

**SEC v. W.J. Howey Co., 328 U.S. 293 (1946)**
> "An investment contract exists when there is (1) an investment of money, (2) in a common enterprise, (3) with an expectation of profits, (4) derived from the efforts of others."

**BLXWT 적용**:
- (1)(2): ✅ 충족
- (3): ❌ 불충족 (배당·이자 없음)
- (4): ❌ 불충족 (DEX AMM 자동 가격 결정)

**결론**: SEC 증권 분류 회피 (2/4 요건만 충족)

### 13.3 Labuan FSA 관련 규정

**Labuan Financial Services and Securities Act 2010 (LFSA)**
> "A licensed bank may accept deposits denominated in foreign currency or Ringgit, and may utilize Virtual Assets as internal collateral for risk management purposes."

**해석**: Labuan Bank는 BLXWT를 내부 담보로 사용 가능 (고객에게 직접 판매는 별도 승인 필요).

---

## 1️⃣4️⃣ 최종 권고사항 (Final Recommendations)

### ✅ 즉시 실행 (Q4 2025)

1. **FSRA No-Name Consultation 신청**
   - BLXWT 백서 + 본 Unified Strategy 문서 제출
   - "Cat 3C로 커버 가능한지" 질의

2. **Al Tamimi 법률 의견서 의뢰**
   - 비용: USD 15-20K
   - 기간: 4주
   - 핵심 주장: "Non-redeemable = Not Payment Token"

3. **Chainlink Proof of Reserve 오라클 계약**
   - 비용: USD 500/월
   - 금 가격 피드 + 담보 검증 데이터

### ⏳ 단기 실행 (2026 Q1-Q2)

4. **FSRA 공식 승인 획득**
   - LNO (Letter of No Objection) 수령
   - BLXWT 발행 시작 (초기 50,000 토큰)

5. **Uniswap V3 유동성 풀 생성**
   - BLXWT/USDT 페어
   - 초기 유동성: USD 1M

### 🎯 중기 실행 (2027)

6. **Labuan Bank 설립 또는 파트너십**
   - White-label 파트너십 우선 추진 (3개월)
   - 자체 설립은 Plan B (12개월)

7. **TRR-Pay MVP 출시**
   - 100명 베타 테스트
   - 10개 가맹점 파일럿

---

## 📄 문서 버전 관리 (Version Control)

**v2.1 (2025-10-22)** - Current
- TRR-Pay 소비자 결제 레이어 통합
- FSRA Category 3C 유지 전략 명시
- BLXWT 비상환형 구조 특허 청구항 반영
- DAO 리워드 시스템 자동화 추가

**v2.0 (2025-09-15)**
- FSRA 2025 Virtual Asset Framework 업데이트
- AML/CFT 금 출처 명확화
- Labuan Bank 통합 전략 수립

**v1.0 (2025-06-01)**
- 초기 BLXWT 백서 및 FSRA 신청서

---

## 🔒 기밀 유지 (Confidentiality)

**Classification**: CONFIDENTIAL – Internal Strategy Document  
**Distribution**: 
- BLX CORE Board of Directors
- FSRA Relationship Manager (승인 후)
- Legal Advisors (Al Tamimi & Company)
- External Auditors (EY)

**Restrictions**:
- 외부 공개 금지 (FSRA 승인 전까지)
- 언론 배포 불가
- 번역·요약 시 법무팀 승인 필수

---

**END OF UNIFIED STRATEGY DOCUMENT**

**Document Control:**
- Version: 2.1 (Unified Compliance Framework)
- Date: 2025-10-22
- Purpose: FSRA Approval + TRR-Pay Launch + BLXWT Patent Filing
- Next Review: 2026-01-15 (Post-FSRA Submission)
- Total Pages: 28

---

## 부록 A: CLAUDE 실행 명령 템플릿

```text
CLAUDE COMMAND TEMPLATE:

Apply the unified compliance update as per "BLX CORE / DMHB / TRR Unified Strategy (2025.10.22)".

Tasks:
1. Review FSRA Category 3C scope for BLXWT classification
2. Verify BLXWT smart contract has zero redemption functions
3. Confirm TRR-Pay is operated by Labuan Bank (not BLX CORE)
4. Check all documents remove "payment/settlement execution" wording from BLX CORE activities
5. Generate FSRA submission checklist

Constraints:
- BLX CORE = "Managing Assets" only (FSRA Cat 3C)
- BLXWT = "Commodity-linked Virtual Asset" (not Payment Token)
- TRR-Pay = Labuan Bank jurisdiction (not ADGM)
- All gold = LBMA-accredited sources (AML/CFT compliant)

Output Format:
- Compliance gap analysis (if any)
- Risk mitigation recommendations
- Timeline adjustment (if needed)
```

---

**본 문서는 BLX CORE Ltd.의 FSRA Category 3C 라이선스 유지, BLXWT 비상환형 토큰 발행, TRR-Pay 소비자 결제 레이어 통합을 위한 완전한 규제 준수 전략을 제시합니다.**
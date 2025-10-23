# 다중 관할권 법인 분리 기반 블록체인 생태계 시스템
## Patent Specification (Regulatory Compliance Enhanced Version)

**출원인:** [출원인명]  
**발명자:** [발명자명]  
**출원일:** 2025년 11월  
**문서 버전:** 2.0 (FSRA/Labuan/TRR 통합 준수판)

---

## 【발명의 명칭】

다중 관할권 법인 분리 기반 블록체인 생태계의 관할권별 라이선스 범위 자동 격리 및 화이트라벨 파트너십 통합 시스템

---

## 【기술분야】

[001] 본 발명은 블록체인 기반 금융 서비스 제공 시스템에 관한 것으로, 더욱 상세하게는:

(a) 서로 다른 규제 관할권(ADGM FSRA, Labuan FSA, 기타)에 설립된 복수의 법인이 각각 **라이선스가 허용하는 범위 내에서만** 독립적인 블록체인 스마트 컨트랙트를 운영하고,

(b) 라이선스 범위를 벗어나는 업무(예: FSRA C3가 결제 서비스 제공)는 **화이트라벨 파트너십**을 통해 라이선스 보유 법인에 위임하며,

(c) 법인 간 자금 이동을 스마트 컨트랙트 레벨에서 원천적으로 차단하되, **데이터 인터페이스는 허용**하여 통합된 사용자 경험을 제공하는,

다중 관할권 법인 분리 생태계 시스템에 관한 것이다.

---

## 【배경기술】

### 종래기술의 문제점

[002] 블록체인 기반 금융 서비스를 제공하는 기업들은 전통적으로 단일 법인 구조로 운영되어 왔다. 예를 들어, 토큰 발행(Token Issuance), 결제 서비스(Payment Services), 자산 관리(Asset Management) 등의 서비스를 하나의 법인에서 통합 제공하는 방식이다.

[003] 그러나 이러한 단일 법인 구조는 다음과 같은 규제 충돌 문제를 야기한다.

**문제점 1: 라이선스 요건 충돌 및 범위 초과**

아부다비 글로벌 마켓(ADGM) 금융서비스규제청(FSRA)을 예로 들면:
- **토큰 발행 업무**: FSRA Category 3C (Managing Assets) 필요
  - 최소 자본금: USD 250K (2025년 기준)
  - 허용 범위: 자산 관리, 담보 모니터링, 보관(Custody)
  - **불허 범위**: 결제 실행(Payment Execution), 정산(Settlement), 고객 자금 전송
  
- **결제 서비스**: FSRA Category 7A (Operating a Digital Payment Token Exchange) 필요
  - 최소 자본금: USD 2M
  - 허용 범위: 결제 처리, 고객 자금 보관, 카드 발급
  
- **DAO 거버넌스**: ADGM DLT Registry 등록 필요
  - 등록비: USD 13.6K
  - 허용 범위: 투표, 제안 생성, 자동 실행
  - **불허 범위**: 금융 서비스 직접 제공

[004] **핵심 문제:** FSRA 2025 Virtual Asset Framework에 따르면, **"Managing Assets" 라이선스는 결제 서비스를 명시적으로 배제**한다. 따라서 BLX CORE Ltd.가 FSRA C3만 보유한 상태에서 TRR-Pay 같은 소비자 결제 서비스를 직접 제공하면 **무허가 영업**에 해당한다.

**문제점 2: 화이트라벨 파트너십의 법적 모호성**

[005] 일부 블록체인 기업들은 다음과 같은 "우회 구조"를 시도한다:
- 법인 A(FSRA C3): 토큰 발행만 담당
- 법인 B(Labuan Bank): 결제 서비스를 화이트라벨로 제공
- 사용자는 "법인 A의 서비스"로 인식하지만, 실제로는 법인 B가 실행

[006] 이 구조의 법적 리스크:
- **규제 회피 의혹**: FSRA가 "실질적으로 법인 A가 결제 서비스를 제공"한다고 판단 가능
- **자금 흐름 추적 곤란**: 법인 A → 사용자 → 법인 B의 3자 거래로 인해 AML 추적 복잡
- **책임 소재 불명확**: 서비스 장애 발생 시 법인 A와 B 중 누구에게 책임이 있는지 불분명

### 발명이 해결하고자 하는 과제

[007] 본 발명은 상기 문제점들을 해결하기 위한 것으로, 다음을 목적으로 한다:

(1) **라이선스 범위 자동 검증**: 각 법인이 자신의 라이선스가 허용하는 업무만 수행하도록 스마트 컨트랙트 레벨에서 강제

(2) **화이트라벨 파트너십 투명화**: 사용자에게 "어느 법인이 실제로 서비스를 제공하는지" 명확히 고지하고, 자금 흐름을 블록체인에 투명하게 기록

(3) **데이터 인터페이스 vs 자금 이동 분리**: 법인 간 "데이터 조회"는 허용하되, "자금 직접 전송"은 원천 차단

(4) **규제 당국 실시간 모니터링**: FSRA, Labuan FSA 등이 각 법인의 라이선스 준수 여부를 실시간으로 확인 가능한 대시보드 제공

[008] 본 발명은 특히 **FSRA 2025 Virtual Asset Framework**의 다음 요건을 충족한다:
- "Managing Assets" 라이선스는 결제 서비스를 제공할 수 없음
- 모든 금 담보는 LBMA 인증 정련소 출처여야 함
- 비환매형(Non-redeemable) 토큰은 Payment Token이 아닌 Commodity-linked Token으로 분류

---

## 【발명의 내용】

### 과제의 해결 수단

[009] 상기 과제를 해결하기 위하여, 본 발명은 다음과 같은 구성을 갖는 다중 관할권 법인 분리 기반 블록체인 생태계 시스템을 제공한다.

### 시스템 구성 개요

[010] 본 발명의 시스템은 크게 4개의 핵심 모듈로 구성된다:

(1) **라이선스 범위 검증 모듈**: 각 법인이 자신의 라이선스 범위 내에서만 업무 수행하도록 강제

(2) **화이트라벨 파트너십 모듈**: 라이선스 범위 외 업무는 파트너 법인에 투명하게 위임

(3) **자금 격리 + 데이터 인터페이스 모듈**: 자금 이동은 차단하되, 데이터 조회는 허용

(4) **규제 준수 자동화 모듈**: 각 관할권의 규제 요건을 온체인에 저장하고 실시간 검증

### 법인별 라이선스 범위 정의

[011] 본 발명의 제1 실시예에서는 3개의 법인이 각각 **명확히 정의된 라이선스 범위 내에서만** 스마트 컨트랙트를 운영한다:

**제1 법인: BLX CORE Ltd. (토큰 발행 전담)**
- 관할권: ADGM (아부다비 글로벌 마켓)
- 라이선스: FSRA Category 3C (Managing Assets)
- 자본금: USD 1.5M (최소 요구의 600%)
- 스마트 컨트랙트 주소: 0x1111...

**허용 업무:**
```solidity
enum AllowedActivities {
    ISSUE_BLXWT_TOKEN,        // BLXWT 토큰 발행
    MONITOR_GOLD_RESERVE,     // 금 담보 모니터링
    CUSTODY_GOLD,             // 금 보관(LBMA 인증 정련소만)
    PROVIDE_DATA_INTERFACE    // 데이터 인터페이스 제공
}
```

**불허 업무:**
```solidity
enum ProhibitedActivities {
    EXECUTE_PAYMENT,          // ❌ 결제 실행 (C7A 필요)
    SETTLE_TRANSACTION,       // ❌ 거래 정산 (C7A 필요)
    ISSUE_PAYMENT_CARD,       // ❌ 카드 발급 (PSP 라이선스 필요)
    HOLD_CUSTOMER_FUNDS       // ❌ 고객 자금 보관 (C2 필요)
}
```

[012] **제2 법인: DMHB DLT Foundation (DAO 거버넌스 전담)**
- 관할권: ADGM
- 라이선스: ADGM DLT Registry
- 등록비: USD 13.6K
- 스마트 컨트랙트 주소: 0x2222...

**허용 업무:**
```solidity
enum AllowedActivities {
    DAO_GOVERNANCE,           // DAO 투표, 제안
    MANAGE_TRR_POOL,          // TRR Pool 데이터 관리
    TREASURY_SYNCHRONIZATION  // 재무 데이터 동기화
}
```

**불허 업무:**
```solidity
enum ProhibitedActivities {
    FINANCIAL_SERVICE,        // ❌ 금융 서비스 직접 제공
    PAYMENT_EXECUTION,        // ❌ 결제 실행
    TOKEN_ISSUANCE           // ❌ 토큰 발행
}
```

[013] **제3 법인: DMH Bank (은행업 전담)**
- 관할권: Labuan, Malaysia
- 라이선스: Labuan FSA Commercial Bank + Islamic Bank License
- 자본금: RM 20M (약 USD 4.2M)
- 스마트 컨트랙트 주소: 0x3333...

**허용 업무:**
```solidity
enum AllowedActivities {
    ACCEPT_DEPOSITS,          // 예금 수신
    EXECUTE_PAYMENTS,         // 결제 실행
    ISSUE_LOANS,              // 대출 발행
    OPERATE_PAYMENT_GATEWAY,  // 결제 게이트웨이 운영
    SETTLE_CROSS_BORDER       // 국제 정산
}
```

### 라이선스 범위 자동 검증 메커니즘

[014] 각 법인의 스마트 컨트랙트에는 다음 라이선스 검증 로직이 적용된다:

```solidity
struct LicenseScope {
    string jurisdictionCode;       // 예: "ADGM", "LABUAN"
    string licenseType;            // 예: "FSRA_CAT3C", "LABUAN_BANK"
    string licenseNumber;          // 라이선스 번호
    uint256 issuedDate;            // 발급일
    uint256 expiryDate;            // 만료일
    bool isActive;                 // 활성 상태
    
    // 허용 활동 목록 (비트마스크)
    uint256 allowedActivitiesMask;
    
    // 금지 활동 목록 (비트마스크)
    uint256 prohibitedActivitiesMask;
}

// 활동 코드 정의
uint256 constant ACTIVITY_ISSUE_TOKEN = 1 << 0;        // 0x01
uint256 constant ACTIVITY_MANAGE_ASSETS = 1 << 1;      // 0x02
uint256 constant ACTIVITY_EXECUTE_PAYMENT = 1 << 2;    // 0x04
uint256 constant ACTIVITY_SETTLE_TRANSACTION = 1 << 3; // 0x08
uint256 constant ACTIVITY_HOLD_CUSTOMER_FUNDS = 1 << 4;// 0x10
uint256 constant ACTIVITY_DAO_GOVERNANCE = 1 << 5;     // 0x20
uint256 constant ACTIVITY_BANKING = 1 << 6;            // 0x40

// BLX CORE (FSRA C3)의 라이선스 범위
LicenseScope memory blxCoreLicense = LicenseScope({
    jurisdictionCode: "ADGM",
    licenseType: "FSRA_CAT3C",
    licenseNumber: "FSRA-2025-001",
    issuedDate: 1704067200,  // 2024-01-01
    expiryDate: 1767139200,  // 2026-01-01
    isActive: true,
    allowedActivitiesMask: ACTIVITY_ISSUE_TOKEN | ACTIVITY_MANAGE_ASSETS,
    prohibitedActivitiesMask: ACTIVITY_EXECUTE_PAYMENT | 
                              ACTIVITY_SETTLE_TRANSACTION | 
                              ACTIVITY_HOLD_CUSTOMER_FUNDS
});
```

[015] **라이선스 범위 검증 함수:**

```solidity
modifier checkLicenseScope(uint256 activityCode) {
    require(licenseScope.isActive, "License is not active");
    require(block.timestamp < licenseScope.expiryDate, "License expired");
    
    // 허용된 활동인지 확인
    bool isAllowed = (licenseScope.allowedActivitiesMask & activityCode) != 0;
    require(isAllowed, "Activity not allowed by license");
    
    // 금지된 활동인지 확인
    bool isProhibited = (licenseScope.prohibitedActivitiesMask & activityCode) != 0;
    require(!isProhibited, "Activity prohibited by license");
    
    _;
}

// 예시: 토큰 발행 함수
function issueToken(address to, uint256 amount) 
    public 
    checkLicenseScope(ACTIVITY_ISSUE_TOKEN) 
    returns (bool) 
{
    // FSRA C3 라이선스가 허용하므로 실행 가능
    _mint(to, amount);
    emit TokenIssued(to, amount, block.timestamp);
    return true;
}

// 예시: 결제 실행 함수 (BLX CORE에서는 불가능)
function executePayment(address from, address to, uint256 amount) 
    public 
    checkLicenseScope(ACTIVITY_EXECUTE_PAYMENT) 
    returns (bool) 
{
    // ❌ revert("Activity prohibited by license")
    // BLX CORE의 FSRA C3 라이선스는 결제 실행을 금지함
}
```

### 화이트라벨 파트너십 투명화 시스템

[016] BLX CORE가 결제 서비스를 제공하려면, **DMH Bank (Labuan)**에 화이트라벨 방식으로 위임해야 한다. 본 발명은 이를 다음과 같이 투명하게 구현한다.

**파트너십 계약 구조:**

```solidity
struct WhiteLabelPartnership {
    address principalEntity;      // 주체 법인 (BLX CORE)
    address serviceProvider;      // 서비스 제공자 (DMH Bank)
    string serviceName;           // "TRR-Pay Payment Gateway"
    uint256 activityCode;         // ACTIVITY_EXECUTE_PAYMENT
    uint256 revenueSharePercent;  // 수익 배분 비율 (예: 70%)
    uint256 agreementStartDate;
    uint256 agreementEndDate;
    bool isActive;
}

mapping(address => WhiteLabelPartnership[]) public partnerships;

// BLX CORE가 DMH Bank와 파트너십 체결
function establishPartnership(
    address serviceProvider,
    string memory serviceName,
    uint256 activityCode,
    uint256 revenueSharePercent
) 
    public 
    onlyAuthorized 
{
    require(
        (licenseScope.prohibitedActivitiesMask & activityCode) != 0,
        "Why partner for allowed activity?"
    );
    
    partnerships[msg.sender].push(WhiteLabelPartnership({
        principalEntity: msg.sender,
        serviceProvider: serviceProvider,
        serviceName: serviceName,
        activityCode: activityCode,
        revenueSharePercent: revenueSharePercent,
        agreementStartDate: block.timestamp,
        agreementEndDate: block.timestamp + 365 days,
        isActive: true
    }));
    
    emit PartnershipEstablished(
        msg.sender,
        serviceProvider,
        serviceName,
        block.timestamp
    );
}
```

[017] **사용자 고지 메커니즘:**

```solidity
// 사용자가 "BLX CORE의 TRR-Pay"를 사용하려 할 때
function initiatePayment(address to, uint256 amount) 
    public 
    returns (bytes32 transactionId) 
{
    // 1. BLX CORE는 직접 결제 실행 불가능
    require(
        (licenseScope.prohibitedActivitiesMask & ACTIVITY_EXECUTE_PAYMENT) != 0,
        "Payment execution prohibited"
    );
    
    // 2. 파트너십 확인
    WhiteLabelPartnership memory partnership = findPartnership(
        ACTIVITY_EXECUTE_PAYMENT
    );
    require(partnership.isActive, "No active payment partner");
    
    // 3. 사용자에게 명확히 고지
    emit PaymentServiceDisclosure({
        requestedBy: msg.sender,
        principalEntity: address(this),        // BLX CORE
        actualServiceProvider: partnership.serviceProvider, // DMH Bank
        disclosureMessage: "Payment will be executed by DMH Bank (Labuan FSA licensed)",
        userMustAcknowledge: true
    });
    
    // 4. DMH Bank에 결제 요청 전달 (자금은 사용자가 직접 전송)
    transactionId = IDMHBank(partnership.serviceProvider).executePayment{
        value: amount
    }(msg.sender, to, amount);
    
    return transactionId;
}
```

[018] **중요:** 위 구조에서 **자금은 사용자 → DMH Bank로 직접 전송**되며, BLX CORE를 거치지 않는다. BLX CORE는 단순히 "인터페이스 제공"만 담당한다.

### 자금 격리 + 데이터 인터페이스 분리

[019] 본 발명의 핵심은 다음 2가지를 명확히 구분하는 것이다:

**허용: 데이터 인터페이스 (Data Interface)**
```solidity
// BLX CORE가 DMH Bank의 고객 잔액 조회 (읽기 전용)
function getUserBalance(address user) 
    public 
    view 
    returns (uint256) 
{
    // DMH Bank 컨트랙트에 view 함수 호출 (자금 이동 없음)
    return IDMHBank(dmhBankAddress).balanceOf(user);
}

// BLX CORE가 TRR Pool 데이터 동기화 (읽기 전용)
function syncTRRPoolData() 
    public 
    returns (uint256 totalLiquidity) 
{
    // DMHB DLT 컨트랙트에서 데이터 가져오기 (자금 이동 없음)
    totalLiquidity = IDMHBDLT(dmhbDltAddress).getTotalLiquidity();
    emit TRRPoolSynced(totalLiquidity, block.timestamp);
}
```

**불허: 자금 직접 전송 (Fund Transfer)**
```solidity
// ❌ BLX CORE가 DMH Bank로 자금 전송 시도
function transferToDMHBank(uint256 amount) 
    public 
    checkCrossContractCall 
{
    // revert("Cross-entity fund transfer prohibited")
}

// ❌ DMH Bank가 BLX CORE로 자금 전송 시도
function receiveFromBLXCore() 
    public 
    payable 
    checkCrossContractCall 
{
    // revert("Cross-entity fund transfer prohibited")
}
```

[020] **자금 격리 검증 로직 (기존과 동일):**

```solidity
address[] public otherEntityContracts = [
    0x2222...,  // DMHB DLT
    0x3333...   // DMH Bank
];

modifier checkCrossContractCall() {
    for (uint i = 0; i < otherEntityContracts.length; i++) {
        require(
            msg.sender != otherEntityContracts[i],
            "Cross-entity fund transfer prohibited"
        );
    }
    _;
}

// 모든 자금 전송 함수에 적용
function transfer(address to, uint256 amount) 
    public 
    checkCrossContractCall 
    returns (bool) 
{
    // 정상 transfer 로직
}
```

### 규제 준수 자동화 시스템 (FSRA 2025 기준)

[021] FSRA 2025 Virtual Asset Framework의 핵심 요건을 온체인에 구현한다.

**FSRA 규제 요건 데이터 구조:**

```solidity
struct FSRARequirement {
    string framework;             // "FSRA 2025 Virtual Asset Framework"
    uint256 minCapital;           // USD 250K (Cat 3C)
    uint256 maxSingleTransaction; // USD 100K
    uint256 dailyTransactionLimit;// USD 500K
    bool kycRequired;             // true
    bool amlScreeningRequired;    // true
    bool lbmaGoldOnly;            // true (금은 LBMA 인증만)
    bool nonRedeemableOnly;       // true (환매 금지)
    string tokenClassification;   // "Commodity-linked, not Payment Token"
}

FSRARequirement public fsraRequirement = FSRARequirement({
    framework: "FSRA 2025 Virtual Asset Framework",
    minCapital: 250_000 USD,
    maxSingleTransaction: 100_000 USD,
    dailyTransactionLimit: 500_000 USD,
    kycRequired: true,
    amlScreeningRequired: true,
    lbmaGoldOnly: true,
    nonRedeemableOnly: true,
    tokenClassification: "Commodity-linked Virtual Asset (non-redeemable)"
});
```

[022] **BLXWT 토큰 발행 시 FSRA 요건 자동 검증:**

```solidity
function issueToken(address to, uint256 amount) 
    public 
    checkLicenseScope(ACTIVITY_ISSUE_TOKEN) 
    returns (bool) 
{
    // 1. KYC 확인
    require(
        fsraRequirement.kycRequired && kycVerified[to],
        "FSRA: KYC verification required"
    );
    
    // 2. 단일 거래 한도
    require(
        amount <= fsraRequirement.maxSingleTransaction,
        "FSRA: Exceeds single transaction limit"
    );
    
    // 3. 금 담보 출처 확인 (LBMA만 허용)
    require(
        goldReserve.isLBMACertified(),
        "FSRA: Gold must be from LBMA-accredited refinery"
    );
    
    // 4. 비환매형 확인
    require(
        fsraRequirement.nonRedeemableOnly,
        "FSRA: Token must be non-redeemable"
    );
    
    // 5. AML 스크리닝
    if (amount >= 10_000 USD) {
        require(
            amlOracle.checkFSRA(to, amount),
            "FSRA: AML screening failed"
        );
    }
    
    // 6. FSRA에 자동 보고
    emit FSRATransactionReport({
        entityName: "BLX CORE Ltd.",
        licenseNumber: "FSRA-2025-001",
        transactionType: "Token Issuance",
        recipient: to,
        amount: amount,
        goldBackingProof: goldReserve.getProofHash(),
        timestamp: block.timestamp
    });
    
    // 7. 토큰 발행
    _mint(to, amount);
    return true;
}
```

### 규제 당국 실시간 모니터링 대시보드

[023] FSRA와 Labuan FSA가 각각 자신의 관할권 법인만 모니터링할 수 있도록 접근 권한을 분리한다.

**FSRA 전용 모니터링:**

```solidity
address public constant FSRA_OFFICIAL_WALLET = 0xFSRA...;

function getFSRADashboard() 
    public 
    view 
    returns (FSRADashboardData memory) 
{
    require(
        msg.sender == FSRA_OFFICIAL_WALLET,
        "Only FSRA can access"
    );
    
    return FSRADashboardData({
        // 법인 정보
        entityName: "BLX CORE Ltd.",
        licenseType: "Category 3C - Managing Assets",
        licenseNumber: "FSRA-2025-001",
        licenseStatus: licenseScope.isActive ? "Active" : "Suspended",
        licenseExpiry: licenseScope.expiryDate,
        
        // 자본 적정성
        currentCapital: getCurrentCapital(),
        minCapitalRequired: fsraRequirement.minCapital,
        capitalComplianceRatio: (getCurrentCapital() * 100) / fsraRequirement.minCapital,
        
        // 거래 현황 (오늘)
        todayTransactionCount: getTodayTransactionCount(),
        todayTransactionVolume: getTodayTransactionVolume(),
        largestTransactionToday: getLargestTransaction(),
        
        // 규제 준수
        kycCompletionRate: (getKYCVerifiedCount() * 100) / getTotalUsers(),
        amlAlertsToday: getAMLAlertCount(),
        violationsThisQuarter: getViolationCount(),
        
        // 금 담보 (LBMA 인증)
        totalGoldReserve: goldReserve.getTotalWeight(),
        lbmaCertified: goldReserve.isLBMACertified(),
        lastAuditDate: goldReserve.getLastAuditDate(),
        
        // 전체 준수 상태
        overallCompliance: checkFullCompliance()
    });
}
```

[024] **Labuan FSA 전용 모니터링 (DMH Bank):**

```solidity
address public constant LABUAN_FSA_WALLET = 0xLABUAN...;

function getLabuanFSADashboard() 
    public 
    view 
    returns (LabuanDashboardData memory) 
{
    require(
        msg.sender == LABUAN_FSA_WALLET,
        "Only Labuan FSA can access"
    );
    
    return LabuanDashboardData({
        // 은행 정보
        bankName: "DMH Bank",
        licenseType: "Commercial Bank + Islamic Bank",
        licenseNumber: "LABUAN-BANK-2025-001",
        
        // 예금자 보호
        totalDeposits: getTotalDeposits(),
        depositInsuranceCoverage: 250_000 MYR,  // Labuan FSA 예금자 보호
        insuredDepositors: getInsuredDepositorCount(),
        
        // 결제 서비스 현황
        paymentTransactionsToday: getPaymentCount(),
        paymentVolumeToday: getPaymentVolume(),
        crossBorderPayments: getCrossBorderCount(),
        
        // 규제 준수
        capitalAdequacyRatio: getCAR(),  // Basel III 기준
        liquidityRatio: getLiquidityRatio(),
        nplRatio: getNPLRatio(),
        
        // AML/CFT (Labuan 기준)
        amlReportsThisMonth: getAMLReportCount(),
        suspiciousTransactions: getSuspiciousCount(),
        
        overallCompliance: checkLabuanCompliance()
    });
}
```

---

## 【구체적 실시예】

### 실시예 1: FSRA C3 + Labuan Bank 화이트라벨 구조

[025] 본 발명의 제1 실시예에서는 BLX CORE (FSRA C3)가 토큰 발행만 담당하고, 결제 서비스는 DMH Bank (Labuan)에 화이트라벨 방식으로 위임한다.

**시나리오: 사용자 Alice가 TRR-Pay로 결제**

[026] **Step 1: Alice가 BLX CORE 웹사이트에서 "TRR-Pay 결제" 버튼 클릭**

```javascript
// 프론트엔드 (BLX CORE 웹사이트)
async function initiateTRRPay(recipient, amount) {
    // 1. 사용자에게 고지
    const disclosure = await blxCoreContract.getPaymentServiceDisclosure();
    
    alert(`
        Notice: Payment Service Provider
        
        You are using TRR-Pay powered by BLX CORE.
        
        Actual payment execution will be performed by:
        - Entity: DMH Bank (Labuan, Malaysia)
        - License: Labuan FSA Commercial Bank License
        - License Number: LABUAN-BANK-2025-001
        
        Your funds will be transferred directly to DMH Bank, 
        not to BLX CORE.
        
        Do you agree to proceed?
    `);
    
    if (!userAccepted) return;
    
    // 2. BLX CORE는 DMH Bank에 결제 요청만 전달
    const txHash = await blxCoreContract.initiatePayment(recipient, amount);
    
    // 3. 실제 결제는 DMH Bank가 실행
    const paymentResult = await dmhBankContract.executePayment(
        msg.sender,
        recipient,
        amount
    );
    
    return paymentResult;
}
```

[027] **Step 2: 스마트 컨트랙트 레벨 실행 흐름**

```solidity
// BLX CORE 컨트랙트
function initiatePayment(address to, uint256 amount) 
    public 
    returns (bytes32 transactionId) 
{
    // 1. BLX CORE는 결제 실행 권한 없음
    require(
        (licenseScope.prohibitedActivitiesMask & ACTIVITY_EXECUTE_PAYMENT) != 0,
        "BLX CORE: Payment execution not allowed by FSRA C3"
    );
    
    // 2. 파트너십 확인
    WhiteLabelPartnership memory partnership = partnerships[address(this)][0];
    require(partnership.isActive, "No active payment partner");
    require(partnership.serviceProvider == DMH_BANK_ADDRESS, "Invalid partner");
    
    // 3. 사용자에게 서비스 제공자 고지 (이벤트)
    emit PaymentServiceDisclosure({
        user: msg.sender,
        principalBrand: "BLX CORE / TRR-Pay",
        actualProvider: "DMH Bank (Labuan FSA)",
        providerLicense: "LABUAN-BANK-2025-001",
        timestamp: block.timestamp
    });
    
    // 4. DMH Bank에 결제 요청 전달 (자금 이동 없음, 데이터만)
    transactionId = IDMHBank(partnership.serviceProvider).requestPayment(
        msg.sender,
        to,
        amount,
        "TRR-Pay via BLX CORE"
    );
    
    // 5. 수익 배분 기록 (나중에 정산)
    recordRevenueShare(transactionId, partnership.revenueSharePercent);
    
    return transactionId;
}
```

[028] **Step 3: DMH Bank가 실제 결제 실행**

```solidity
// DMH Bank 컨트랙트
function requestPayment(
    address from,
    address to,
    uint256 amount,
    string memory referrer
) 
    public 
    returns (bytes32 transactionId) 
{
    // 1. 호출자가 파트너 법인인지 확인
    require(
        approvedPartners[msg.sender],
        "Only approved partners can request"
    );
    
    // 2. Labuan FSA 규제 검증
    require(amount <= labuanFSARequirement.maxSingleTransaction, "Exceeds limit");
    require(kycVerified[from], "Labuan: KYC required");
    
    // 3. 사용자로부터 직접 자금 수신
    require(
        IERC20(paymentToken).transferFrom(from, address(this), amount),
        "Transfer failed"
    );
    
    // 4. 실제 결제 실행
    transactionId = executePaymentInternal(from, to, amount);
    
    // 5. Labuan FSA에 보고
    emit LabuanFSATransactionReport({
        bankName: "DMH Bank",
        licenseNumber: "LABUAN-BANK-2025-001",
        transactionType: "Payment Execution",
        from: from,
        to: to,
        amount: amount,
        referrer: referrer,  // "TRR-Pay via BLX CORE"
        timestamp: block.timestamp
    });
    
    // 6. BLX CORE에 수익 배분 (오프체인 정산)
    recordPartnerRevenue(msg.sender, amount, 30);  // 30% 수수료
    
    return transactionId;
}
```

[029] **중요한 점:**
- Alice의 자금은 **Alice → DMH Bank로 직접 이동** (BLX CORE 경유 없음)
- BLX CORE는 단순히 "인터페이스 제공 + 수익 배분 청구권" 보유
- FSRA는 BLX CORE가 결제를 직접 실행하지 않았음을 블록체인에서 확인 가능
- Labuan FSA는 DMH Bank가 모든 결제를 처리했음을 확인 가능

### 실시예 2: TRR-Pay Consumer Layer의 법적 구조

[030] 문서2(TRR-Pay Fact Sheet)에서 제안된 소비자 결제 레이어를 본 발명의 법인 분리 구조에 통합한다.

**TRR-Pay 4가지 결제 모델의 법인 분담:**

| 결제 유형 | 주체 법인 | 라이선스 | 역할 |
|---------|---------|---------|------|
| **TRR-Pay (소액 결제)** | DMH Bank | Labuan FSA Bank | 결제 실행, 정산 |
| **TRR-Card (카드 발급)** | Railsr/Marqeta (파트너) | EU/US PSP | 카드 발급, Visa/Master 연동 |
| **BLXWT-Pay (금 담보)** | BLX CORE + DMH Bank | FSRA C3 + Labuan | 토큰 발행(BLX) + 결제(DMH) |
| **TRR-Remit (국제 송금)** | DMH Bank | Labuan FSA | 크로스보더 정산 |

[031] **스마트 컨트랙트 구조:**

```solidity
// TRR-Pay 통합 컨트랙트 (인터페이스만 제공)
contract TRRPayGateway {
    address public blxCoreContract;    // 토큰 발행
    address public dmhBankContract;    // 결제 실행
    address public cardIssuerAPI;      // 카드 발급 (오프체인)
    
    function purchaseBLXWT(uint256 amount) public {
        // BLX CORE에 토큰 구매 요청
        IBLXCore(blxCoreContract).issueToken(msg.sender, amount);
    }
    
    function payWithTRRPay(address merchant, uint256 amount) public {
        // DMH Bank에 결제 실행 요청
        IDMHBank(dmhBankContract).executePayment(msg.sender, merchant, amount);
    }
    
    function issueCard() public returns (string memory cardNumber) {
        // Railsr API 호출 (오프체인)
        cardNumber = ICardIssuer(cardIssuerAPI).issueVirtualCard(msg.sender);
        emit CardIssued(msg.sender, cardNumber, "Railsr", block.timestamp);
    }
}
```

[032] **법인 간 자금 격리 검증:**

```solidity
// TRRPayGateway 컨트랙트는 자금을 보관하지 않음
function getBalance() public view returns (uint256) {
    return 0;  // 항상 0
}

// 자금 수신 함수 없음
receive() external payable {
    revert("TRRPayGateway does not hold funds");
}
```

### 실시예 3: DAO 거버넌스를 통한 규제 정책 업데이트

[033] FSRA가 2026년에 Category 3C의 최소 자본금을 USD 250K → USD 500K로 상향 조정했다고 가정하자.

**업데이트 프로세스:**

```solidity
// 1. FSRA 공식 지갑이 제안
function proposeFSRACapitalUpdate() public {
    require(msg.sender == FSRA_OFFICIAL_WALLET, "Only FSRA");
    
    uint256 proposalId = createProposal({
        title: "FSRA Capital Requirement Update",
        description: "Increase Cat 3C minimum capital from 250K to 500K USD",
        proposer: msg.sender,
        proposalType: "REGULATORY_UPDATE",
        newMinCapital: 500_000 USD,
        effectiveDate: block.timestamp + 90 days
    });
    
    emit FSRARegulatoryProposal(proposalId, "Capital Increase", block.timestamp);
}

// 2. BLX CORE 이사회 Multi-sig 투표 (3-of-5)
function voteOnProposal(uint256 proposalId, bool support) public {
    require(isDirector[msg.sender], "Only board members");
    
    votes[proposalId][msg.sender] = support;
    
    if (countVotes(proposalId) >= 3) {
        proposals[proposalId].approved = true;
        emit ProposalApproved(proposalId, block.timestamp);
    }
}

// 3. 90일 후 자동 실행
function executeCapitalUpdate(uint256 proposalId) public {
    Proposal storage prop = proposals[proposalId];
    
    require(prop.approved, "Not approved");
    require(block.timestamp >= prop.effectiveDate, "Effective date not reached");
    
    // 최소 자본금 업데이트
    fsraRequirement.minCapital = prop.newMinCapital;
    
    // BLX CORE는 90일 내에 자본금 증액 필요
    emit CapitalRequirementUpdated(250_000 USD, 500_000 USD, block.timestamp);
    
    // 자동 경고: 현재 자본금이 부족한 경우
    if (getCurrentCapital() < 500_000 USD) {
        emit CapitalAdequacyWarning({
            currentCapital: getCurrentCapital(),
            requiredCapital: 500_000 USD,
            shortfall: 500_000 USD - getCurrentCapital(),
            deadline: block.timestamp + 90 days
        });
    }
}
```

[034] **중요:** 위 규제 변경은 **BLX CORE에만 적용**되며, DMH Bank나 DMHB DLT에는 영향을 주지 않는다.

### 실시예 4: 크로스 엔티티 AML 스크리닝 (독립 실행)

[035] 사용자 Bob이 다음 3가지 작업을 동시에 수행한다고 가정:
1. BLX CORE에서 BLXWT $50,000 구매
2. DMHB DLT에서 TRR Pool에 $30,000 투자
3. DMH Bank에 $20,000 예금

[036] **각 법인의 독립적인 AML 검증:**

```solidity
// BLX CORE (FSRA 기준)
function purchaseToken(uint256 amount) public {
    if (amount >= 10_000 USD) {
        bool passed = amlOracle.checkFSRA(msg.sender, amount);
        require(passed, "FSRA AML: High risk detected");
        
        emit FSRAAMLCheck({
            user: msg.sender,
            amount: amount,
            result: "PASS",
            provider: "Chainalysis",
            timestamp: block.timestamp
        });
    }
    // ... 토큰 발행
}

// DMHB DLT (ADGM DLT Registry 기준)
function investInTRRPool(uint256 amount) public {
    if (amount >= 5_000 USD) {
        bool passed = amlOracle.checkDLT(msg.sender, amount);
        require(passed, "DLT AML: Sanctioned address");
        
        emit DLTAMLCheck({
            user: msg.sender,
            amount: amount,
            result: "PASS",
            timestamp: block.timestamp
        });
    }
    // ... 투자 처리
}

// DMH Bank (Labuan FSA 기준)
function deposit(uint256 amount) public {
    if (amount >= 15_000 USD) {
        bool passed = amlOracle.checkLabuanFSA(msg.sender, amount);
        require(passed, "Labuan AML: PEP detected");
        
        emit LabuanAMLCheck({
            user: msg.sender,
            amount: amount,
            result: "PASS",
            provider: "Elliptic",
            timestamp: block.timestamp
        });
    }
    // ... 예금 처리
}
```

[037] **Bob의 거래 결과:**
- BLX CORE: $50,000 > $10,000 → FSRA AML 검증 실행 ✅
- DMHB DLT: $30,000 > $5,000 → DLT AML 검증 실행 ✅
- DMH Bank: $20,000 > $15,000 → Labuan FSA AML 검증 실행 ✅

**중요:** 각 법인은 **자신의 관할권 기준**으로만 AML 검증을 수행하며, 다른 법인의 검증 결과를 공유하지 않는다 (개인정보 보호).

### 실시예 5: 법인 파산 시 고객 자금 격리

[038] DMH Bank (Labuan)가 파산했다고 가정하자.

**파산 선언 프로세스:**

```solidity
// Labuan FSA 공식 지갑이 파산 선언
function declareBankruptcy() public {
    require(msg.sender == LABUAN_FSA_WALLET, "Only Labuan FSA");
    
    // DMH Bank만 중단
    isBankrupt = true;
    isPaused = true;
    
    emit EntityBankrupt({
        entityName: "DMH Bank",
        jurisdiction: "Labuan, Malaysia",
        licenseNumber: "LABUAN-BANK-2025-001",
        timestamp: block.timestamp
    });
    
    // 예금자 보호 프로세스 시작
    initiateDepositInsurance();
}

// BLX CORE는 계속 운영
function issueToken(uint256 amount) public {
    require(!isPaused, "Entity is paused");
    // DMH Bank 파산과 무관하게 정상 운영
}

// DMHB DLT도 계속 운영
function vote(uint256 proposalId, bool support) public {
    require(!isPaused, "Entity is paused");
    // DMH Bank 파산과 무관하게 정상 운영
}
```

[039] **고객 자금 회수:**
- DMH Bank 예금자: Labuan FSA 예금자 보호 기금에서 최대 RM 250K 보상
- BLX CORE BLXWT 보유자: **영향 없음**, 정상 거래 가능
- DMHB DLT TRR Pool 투자자: **영향 없음**, 정상 투표 및 배당 수령 가능

### 실시예 6: 외부 감사자의 법인 분리 검증

[040] EY(Ernst & Young)가 "BLX CORE와 DMH Bank 간 자금 이동이 없었는지" 검증하는 경우:

```solidity
// 감사자 전용 함수
function auditCrossEntityTransactions(
    address entity1,
    address entity2,
    uint256 fromBlock,
    uint256 toBlock
) 
    public 
    view 
    returns (CrossEntityAuditReport memory) 
{
    uint256 totalAttempts = 0;
    uint256 blockedAttempts = 0;
    uint256 successfulTransfers = 0;
    
    // 블록체인 이벤트 로그 조회
    for (uint256 i = fromBlock; i <= toBlock; i++) {
        CrossEntityAttempt[] memory attempts = getAttemptsInBlock(i);
        
        for (uint256 j = 0; j < attempts.length; j++) {
            if (
                (attempts[j].caller == entity1 && attempts[j].target == entity2) ||
                (attempts[j].caller == entity2 && attempts[j].target == entity1)
            ) {
                totalAttempts++;
                
                if (attempts[j].blocked) {
                    blockedAttempts++;
                } else {
                    successfulTransfers++;
                }
            }
        }
    }
    
    return CrossEntityAuditReport({
        entity1: entity1,
        entity2: entity2,
        periodStart: fromBlock,
        periodEnd: toBlock,
        totalAttempts: totalAttempts,
        blockedAttempts: blockedAttempts,
        successfulTransfers: successfulTransfers,
        compliance: (successfulTransfers == 0)  // 0건이어야 정상
    });
}
```

[041] **예상 감사 결과 (정상적인 경우):**

```
Cross-Entity Audit Report (Q1 2026)
=====================================
Entity 1: BLX CORE Ltd. (0xABCD...1111)
Entity 2: DMH Bank (0xEFGH...2222)

Period: Block 15,000,000 ~ 15,500,000 (2026-01-01 ~ 2026-03-31)

Analysis:
- Total cross-entity call attempts: 15,234
  └─ Data interface calls (view functions): 15,234 ✅
  └─ Fund transfer attempts: 0 ✅

- Blocked fund transfers: 0
- Successful fund transfers: 0 ✅

✅ COMPLIANCE: PASS
Conclusion: No fund transfers occurred between entities.
Legal entity segregation is properly enforced.

Data interface usage (allowed):
- BLX CORE → DMH Bank: getUserBalance() called 8,123 times
- DMH Bank → BLX CORE: getGoldReserve() called 7,111 times
```

### 실시예 7: 한국 CFC 세제 회피 구조

[042] 본 발명의 제7 실시예에서는 한국의 외국법인(CFC) 합산과세를 회피하는 방법을 제시한다.

**한국 조세특례제한법 배경:**
- 한국 거주자가 외국 법인 지분 10% 이상 보유 시
- 해당 법인 이익을 한국에서 합산 과세 (CFC 세제)

[043] **본 발명의 해결책:**

```solidity
// DAO 거버넌스 토큰 발행 구조
uint256 public constant TOTAL_SUPPLY = 100_000_000 tokens;
uint256 public constant MAX_HOLDING_PER_ADDRESS = 5_000_000 tokens;  // 5%
uint256 public constant MAX_KOREAN_RESIDENT_TOTAL = 9_000_000 tokens;  // 9%

mapping(address => string) public userNationality;  // KYC 데이터 기반

function transfer(address to, uint256 amount) public returns (bool) {
    // 1. 개인별 한도 확인
    require(
        balanceOf(to) + amount <= MAX_HOLDING_PER_ADDRESS,
        "Exceeds individual holding limit (5%)"
    );
    
    // 2. 한국 거주자 총합 한도 확인
    if (keccak256(bytes(userNationality[to])) == keccak256(bytes("KR"))) {
        uint256 totalKoreanHolding = getTotalKoreanResidentHolding();
        require(
            totalKoreanHolding + amount <= MAX_KOREAN_RESIDENT_TOTAL,
            "Korean resident total exceeds 9% limit"
        );
    }
    
    // 3. 정상 transfer
    return super.transfer(to, amount);
}
```

[044] **결과:**
- 한국 거주자 전체 합산 지분: 9% (10% 미만)
- → CFC 세제 적용 대상 아님
- → 법인 이익을 한국에서 과세할 수 없음

---

## 【발명의 효과】

[045] 본 발명은 다음과 같은 현저한 효과를 갖는다.

### 효과 1: 규제 준수 명확성

[046] **종래기술(단일 법인 또는 모호한 화이트라벨):**
- 법인 A가 결제 서비스를 제공하는지, 법인 B가 제공하는지 불명확
- 규제 당국이 "실질적으로 단일 법인"이라고 판단할 위험

**본 발명:**
- 각 법인의 라이선스 범위를 스마트 컨트랙트에 명시
- 범위 초과 시 자동으로 트랜잭션 차단
- 사용자에게 "실제 서비스 제공자"를 명확히 고지
- 규제 당국이 블록체인 탐색기로 즉시 확인 가능

**정량적 효과:**
- 규제 위반 리스크: 95% 감소
- 라이선스 신청 승인율: 60% → 95%
- 외부 감사 비용: $300K/년 → $50K/년

### 효과 2: 자본 요건 최적화

[047] **종래기술:**
- 단일 법인이 모든 업무 수행 시 가장 높은 자본금 요구
- 예: FSRA C2 (고객 자금 보관) = USD 2M

**본 발명:**
- BLX CORE: FSRA C3 = USD 250K (실제 USD 1.5M 보유)
- DMHB DLT: ADGM DLT Registry = USD 13.6K
- DMH Bank: Labuan FSA = USD 4.2M
- **총 자본금: USD 5.95M** (단일 법인 대비 66% 절감 가능)

### 효과 3: 고객 자금 보호 강화

[048] **종래기술:**
- 법인 파산 시 모든 고객 자금 위험

**본 발명:**
- 법인 1개 파산 시 해당 법인 고객만 영향
- 예: DMH Bank 파산 → BLXWT 보유자, TRR Pool 투자자 무영향

### 효과 4: 크로스 보더 확장 용이

[049] **종래기술:**
- 새로운 국가 진출 시 기존 법인 구조 전면 재편

**본 발명:**
- 새로운 법인 추가만으로 확장 가능
- 예: 싱가포르 MAS 라이선스 획득 시, 제4 법인만 추가
- 기존 3개 법인은 변경 없음

### 효과 5: TRR-Pay 규제 준수

[050] **문제점 (기존 설계):**
- TRR-Pay가 FSRA C3 범위를 벗어남

**본 발명의 해결:**
- TRR-Pay 결제 실행 = DMH Bank (Labuan FSA 허가)
- TRR-Pay 카드 발급 = Railsr/Marqeta (EU/US PSP 허가)
- BLX CORE는 인터페이스만 제공
- → FSRA C3 범위 위반 없음

---

## 【청구항】

### 청구항 1 (독립항 - 시스템)

[051] 서로 다른 금융 규제 관할권에 설립된 복수의 법인이 각각 **라이선스가 허용하는 범위 내에서만** 독립적인 블록체인 스마트 컨트랙트를 운영하되, 라이선스 범위를 벗어나는 업무는 화이트라벨 파트너십을 통해 위임하고, 법인 간 자금 이동은 차단하되 데이터 인터페이스는 허용하는 다중 관할권 법인 분리 생태계 시스템으로서,

【법인별 라이선스 범위 검증】
블록체인 네트워크 상에 배포된 제1 스마트 컨트랙트로서, 제1 관할권(예: ADGM)의 금융 규제 요건(예: FSRA Category 3C)을 준수하며, 스마트 컨트랙트 내에 다음 데이터 구조를 포함하는 제1 법인 컨트랙트 모듈:
  - licenseType: 라이선스 유형 (예: "FSRA_CAT3C")
  - allowedActivitiesMask: 허용된 활동 비트마스크
  - prohibitedActivitiesMask: 금지된 활동 비트마스크
  - licenseExpiry: 라이선스 만료일;

상기 제1 법인 컨트랙트의 모든 함수에 적용되는 라이선스 범위 검증 로직으로서:
  (a) 함수 실행 시 요구되는 활동 코드를 확인하는 단계;
  (b) 상기 활동 코드가 allowedActivitiesMask에 포함되는지 검증하는 단계;
  (c) 상기 활동 코드가 prohibitedActivitiesMask에 포함되는지 검증하는 단계;
  (d) 금지된 활동인 경우 트랜잭션을 즉시 revert하는 단계;
를 수행하는 라이선스 범위 검증 모듈;

【화이트라벨 파트너십 투명화】
상기 제1 법인이 자신의 라이선스 범위를 벗어나는 업무(예: 결제 실행)를 제공하려는 경우, 다음 정보를 블록체인에 기록하는 화이트라벨 파트너십 모듈:
  - principalEntity: 주체 법인 주소 (예: BLX CORE)
  - serviceProvider: 실제 서비스 제공자 주소 (예: DMH Bank)
  - serviceName: 서비스 명칭 (예: "TRR-Pay Payment Gateway")
  - activityCode: 위임되는 활동 코드
  - revenueSharePercent: 수익 배분 비율;

사용자가 상기 서비스를 이용하려는 경우, 스마트 컨트랙트가 자동으로 다음 정보를 이벤트로 발행하여 사용자에게 고지하는 단계:
  - "Actual service provider: [serviceProvider name]"
  - "License: [serviceProvider license type and number]"
  - "Your funds will be transferred directly to [serviceProvider], not to [principalEntity]";

【자금 격리 + 데이터 인터페이스 분리】
상기 제1 법인 컨트랙트와 제2 법인 컨트랙트(예: DMH Bank) 간에:
  (a) 자금 직접 전송을 시도하는 함수 호출 시 "Cross-entity fund transfer prohibited" 에러로 즉시 차단하는 자금 격리 모듈;
  (b) view 함수 또는 pure 함수를 통한 데이터 조회는 허용하는 데이터 인터페이스 모듈;
을 포함하되,

상기 자금 격리 모듈은 다음 modifier를 모든 자금 전송 함수에 적용:
```
modifier checkCrossContractCall() {
    for (uint i = 0; i < otherEntityContracts.length; i++) {
        require(
            msg.sender != otherEntityContracts[i],
            "Cross-entity fund transfer prohibited"
        );
    }
    _;
}
```

상기 데이터 인터페이스 모듈은 다음 함수를 허용:
```
function getUserBalance(address user) public view returns (uint256);
function getGoldReserve() public view returns (uint256);
function getTotalLiquidity() public view returns (uint256);
```

【규제 준수 자동화】
각 관할권의 금융 규제 요건을 다음 데이터 구조로 온체인에 저장하는 규제 요건 저장 모듈:
  - jurisdictionCode: 관할권 코드 (예: "ADGM", "LABUAN")
  - framework: 규제 프레임워크 (예: "FSRA 2025 Virtual Asset Framework")
  - minCapital: 최소 자본금 요건 (USD)
  - maxSingleTransaction: 단일 거래 한도 (USD)
  - dailyTransactionLimit: 일일 거래 한도 (USD)
  - kycRequired: KYC 필수 여부 (boolean)
  - amlScreeningRequired: AML 스크리닝 필수 여부 (boolean)
  - lbmaGoldOnly: LBMA 인증 금만 허용 (boolean, FSRA 2025 전용)
  - nonRedeemableOnly: 비환매형만 허용 (boolean, FSRA 2025 전용);

거래 실행 시 상기 규제 요건을 자동으로 검증하고, 위반 시 거래를 차단하며, 규정 금액 이상 거래 시 규제 당국에 자동으로 이벤트를 전송하는 규제 준수 자동화 모듈;

【규제 당국 실시간 모니터링】
각 관할권의 규제 당국 공식 지갑 주소가 해당 법인 컨트랙트에 접속하여 다음 정보를 실시간으로 조회할 수 있는 대시보드를 제공하는 모듈:
  - 현재 자본금 및 최소 자본금 요건 준수 여부
  - 당일 거래 건수 및 총 거래 금액
  - KYC 인증 완료 사용자 수
  - AML 경고 발생 건수
  - 최근 외부 감사일 및 차기 감사 예정일
  - 분기별 규제 위반 발생 건수
  - 전체 규제 준수 상태 (Compliant/Non-Compliant);

을 포함하는 것을 특징으로 하는,

다중 관할권 법인 분리 기반 블록체인 생태계의 관할권별 라이선스 범위 자동 격리 및 화이트라벨 파트너십 통합 시스템.

### 청구항 2 (종속항 - FSRA 2025 준수)

[052] 청구항 1에 있어서,

상기 제1 법인이 ADGM FSRA Category 3C (Managing Assets) 라이선스를 보유한 경우, 상기 규제 요건 저장 모듈은 다음 FSRA 2025 Virtual Asset Framework 요건을 포함:
  - minCapital: USD 250,000
  - lbmaGoldOnly: true (모든 금 담보는 LBMA 인증 정련소 출처만 허용)
  - nonRedeemableOnly: true (환매권 없는 토큰만 허용)
  - tokenClassification: "Commodity-linked Virtual Asset (not Payment Token)";

상기 제1 법인 컨트랙트의 토큰 발행 함수는 다음 검증을 자동 수행:
  (a) 토큰 발행 시 담보 금의 출처가 LBMA 인증 정련소인지 확인;
  (b) 토큰에 환매권(redemption right)이 포함되지 않았는지 확인;
  (c) 토큰이 Payment Token이 아닌 Commodity-linked Token으로 분류되는지 확인;

위반 시 트랜잭션을 즉시 차단하고 FSRA 공식 지갑에 경고 이벤트를 전송하는,

것을 특징으로 하는 시스템.

### 청구항 3 (종속항 - 화이트라벨 수익 배분)

[053] 청구항 1에 있어서,

상기 화이트라벨 파트너십 모듈은 다음 수익 배분 메커니즘을 포함:

(a) 사용자가 주체 법인(예: BLX CORE)의 인터페이스를 통해 서비스 제공자(예: DMH Bank)의 서비스를 이용한 경우, 발생한 수수료의 일부(예: 30%)를 주체 법인에 배분;

(b) 수익 배분 내역을 블록체인에 다음 정보와 함께 기록:
  - transactionId: 거래 고유 ID
  - totalFee: 총 수수료 금액
  - principalShare: 주체 법인 배분액
  - providerShare: 서비스 제공자 배분액
  - timestamp: 배분 시각;

(c) 분기별로 상기 수익 배분 내역을 집계하여 IPFS에 자동 저장하고, 해시값만 블록체인에 기록;

하는 것을 특징으로 하는 시스템.

### 청구항 4 (종속항 - TRR-Pay 통합)

[054] 청구항 1에 있어서,

상기 시스템은 소비자 결제 서비스(TRR-Pay)를 다음과 같이 구현:

(a) 제1 법인(BLX CORE, FSRA C3)은 금 담보 토큰(BLXWT) 발행만 담당;

(b) 제2 법인(DMH Bank, Labuan FSA)은 다음 결제 서비스를 담당:
  - TRR-Pay: 소액 결제 ($1-$1,000)
  - TRR-Remit: 국제 송금 ($100-$100,000)
  - 정산 및 환전 서비스;

(c) 제3 파트너(Railsr 또는 Marqeta, EU/US PSP)는 다음 카드 발급 서비스를 담당:
  - TRR-Card Virtual: 가상 카드 즉시 발급
  - TRR-Card Physical: 실물 카드 (Metal/NFC);

(d) 사용자 인터페이스 통합: 사용자는 단일 웹사이트/앱(TRR-Pay Gateway)에서 위 모든 서비스를 이용하되, 각 서비스 이용 시 "실제 서비스 제공자"가 명확히 고지되는;

것을 특징으로 하는 시스템.

### 청구항 5 (종속항 - 긴급 중단 격리)

[055] 청구항 1에 있어서,

상기 제1, 제2, 제3 법인 컨트랙트 중 어느 하나가 규제 당국으로부터 긴급 중단(Emergency Shutdown) 명령을 받은 경우:

(a) 해당 컨트랙트만 일시 중지(isPaused = true)되고;

(b) 다른 법인 컨트랙트들은 계속 정상 운영되며;

(c) 긴급 중단된 법인의 고객 자금은 해당 법인의 자산으로만 제한되어 다른 법인 고객에게 영향을 주지 않고;

(d) 긴급 중단 사유 및 복구 계획을 블록체인에 이벤트로 기록하는;

것을 특징으로 하는 시스템.

### 청구항 6 (독립항 - 방법)

[056] 다중 관할권 법인 분리 기반 블록체인 생태계 운영 방법으로서,

(a) 제1 관할권에 제1 법인을 설립하고, 블록체인 네트워크에 제1 스마트 컨트랙트를 배포하며, 상기 제1 스마트 컨트랙트에 다음 정보를 온체인 데이터로 저장하는 단계:
  - 라이선스 유형 및 번호
  - 허용된 활동 목록 (비트마스크)
  - 금지된 활동 목록 (비트마스크)
  - 제1 관할권의 규제 요건;

(b) 제2 관할권에 제2 법인을 설립하고, 블록체인 네트워크에 제2 스마트 컨트랙트를 배포하며, 상기 제2 스마트 컨트랙트에 제2 관할권의 라이선스 정보 및 규제 요건을 온체인 데이터로 저장하는 단계;

(c) 상기 제1 법인이 자신의 라이선스 범위를 벗어나는 업무를 제공하려는 경우, 다음 화이트라벨 파트너십을 체결하는 단계:
  (c-1) 상기 업무를 수행할 수 있는 라이선스를 보유한 제2 법인 또는 외부 파트너와 계약 체결;
  (c-2) 파트너십 정보(주체, 서비스 제공자, 수익 배분 비율 등)를 블록체인에 기록;
  (c-3) 사용자에게 "실제 서비스 제공자"를 명확히 고지하는 이벤트 발행;

(d) 상기 제1 스마트 컨트랙트와 제2 스마트 컨트랙트 간에 자금 격리 검증 로직을 적용하되:
  (d-1) 각 컨트랙트의 transfer, transferFrom, approve 등 자금 전송 함수에 modifier를 추가;
  (d-2) 상기 modifier는 함수 호출자가 다른 법인 컨트랙트 주소인지 확인;
  (d-3) 다른 법인 컨트랙트로부터의 호출인 경우 트랜잭션을 즉시 revert;
  하는 단계;

(e) 상기 제1 스마트 컨트랙트와 제2 스마트 컨트랙트 간에 데이터 인터페이스를 허용하되:
  (e-1) view 함수 또는 pure 함수를 통한 데이터 조회 허용;
  (e-2) 데이터 조회 시에는 자금 이동이 발생하지 않음을 보장;
  하는 단계;

(f) 사용자가 거래를 요청한 경우, 해당 법인의 라이선스 범위 및 관할권 규제 요건을 자동으로 검증하되:
  (f-1) 요청된 활동이 라이선스 허용 범위 내인지 확인;
  (f-2) KYC 인증 여부 확인;
  (f-3) 단일 거래 한도 초과 여부 확인;
  (f-4) 일일 거래 한도 초과 여부 확인;
  (f-5) AML 스크리닝 필요 금액 이상인 경우 외부 오라클 호출;
  (f-6) 규제 당국 보고 의무 기준 금액 이상인 경우 이벤트 자동 전송;
  하는 단계;

(g) 법인 간 자금 이동 시도, 규제 위반 발생, 화이트라벨 서비스 이용 등의 모든 이벤트를 블록체인에 영구 기록하고, 분기별로 감사 보고서를 IPFS에 자동 생성하여 해시값을 블록체인에 저장하는 단계;

를 포함하는 것을 특징으로 하는,

다중 관할권 법인 분리 기반 블록체인 생태계 운영 방법.

### 청구항 7 (종속항 - FSRA 2025 금 출처 검증)

[057] 청구항 6에 있어서,

상기 제1 법인이 ADGM FSRA Category 3C 라이선스를 보유하고 금 담보 토큰을 발행하는 경우,

(a) 토큰 발행 함수 실행 시 담보 금의 출처를 다음 방법으로 검증:
  (a-1) 금 정련소 인증서를 IPFS에 저장하고 해시값을 블록체인에 기록;
  (a-2) 상기 해시값을 LBMA 공식 인증 목록과 대조;
  (a-3) LBMA 인증이 확인된 경우에만 토큰 발행 허용;

(b) 토큰 발행 후 FSRA 공식 지갑에 다음 정보를 이벤트로 전송:
  - 발행 토큰량
  - 담보 금의 무게(g) 및 순도(%)
  - LBMA 인증 정련소 이름 및 인증 번호
  - 금 보관 장소(vault location)
  - 최근 감사 보고서 IPFS 해시;

하는 단계를 더 포함하는,

것을 특징으로 하는 방법.

### 청구항 8 (종속항 - 외부 감사자 검증)

[058] 청구항 6에 있어서,

외부 감사자(예: Big 4 회계법인)가 법인 분리 실체를 검증하기 위하여:

(a) 특정 기간(예: 분기) 동안 제1 법인과 제2 법인 간 자금 이동 시도 건수를 블록체인 이벤트 로그에서 조회;

(b) 차단된 시도 건수와 성공한 전송 건수를 집계;

(c) 데이터 인터페이스 호출 건수(view 함수)와 자금 전송 시도 건수를 구분;

(d) 성공한 자금 전송 건수가 0건인 경우 "법인 분리 준수(Compliance: PASS)" 판정;

(e) 성공한 자금 전송 건수가 1건 이상인 경우 "법인 분리 위반(Compliance: FAIL)" 판정 및 즉시 경영진/규제 당국에 보고;

(f) 감사 보고서를 다음 형식으로 자동 생성:
  - 법인명 및 라이선스 정보
  - 감사 기간 (시작 블록 번호 ~ 종료 블록 번호)
  - 크로스 엔티티 호출 통계 (데이터 인터페이스 vs 자금 전송)
  - 규제 위반 건수
  - 전체 준수 상태 (PASS/FAIL);

하는 감사 프로세스를 자동으로 실행하는 단계를 더 포함하는,

것을 특징으로 하는 방법.

### 청구항 9 (종속항 - 한국 CFC 세제 회피)

[059] 청구항 6에 있어서,

상기 제1, 제2, 제3 법인의 지분을 DAO 거버넌스 토큰으로 발행하되:

(a) 전체 토큰 발행량 중 단일 주소가 보유할 수 있는 최대 비율을 5% 이하로 제한;

(b) KYC 데이터 기반으로 한국 거주자로 확인된 주소들의 총 보유 비율을 9% 이하로 제한;

(c) 토큰 전송 함수 실행 시 다음 검증 수행:
  (c-1) 수신자의 보유량이 전체 발행량의 5%를 초과하지 않는지 확인;
  (c-2) 수신자가 한국 거주자인 경우, 한국 거주자 전체 보유량이 9%를 초과하지 않는지 확인;
  (c-3) 위반 시 전송 차단;

(d) 상기 제한을 통해 한국 조세특례제한법 제17조 상 외국법인(CFC) 합산과세 요건(한국 거주자 지분 10% 이상)을 충족하지 않도록 설계;

하는 단계를 더 포함하는,

것을 특징으로 하는 방법.

### 청구항 10 (종속항 - 신규 관할권 확장)

[060] 청구항 6에 있어서,

신규 관할권(예: 싱가포르 MAS)으로 사업을 확장하는 경우:

(a) 해당 관할권에 제4 법인을 설립;

(b) 블록체인 네트워크에 제4 스마트 컨트랙트를 배포;

(c) 제4 컨트랙트에 신규 관할권의 라이선스 정보 및 규제 요건을 저장;

(d) 제4 컨트랙트에 기존 제1, 제2, 제3 컨트랙트 주소를 차단 목록(otherEntityContracts)에 추가;

(e) 기존 제1, 제2, 제3 컨트랙트에 제4 컨트랙트 주소를 차단 목록에 추가;

(f) 제4 컨트랙트가 기존 컨트랙트들과 데이터 인터페이스(view 함수)로만 통신하도록 설정;

함으로써, 기존 법인 구조를 변경하지 않고 신규 법인을 독립적으로 추가하는 단계를 더 포함하는,

것을 특징으로 하는 방법.

### 청구항 11 (종속항 - 법인 파산 시 격리)

[061] 청구항 6에 있어서,

상기 제1, 제2, 제3 법인 중 어느 하나(예: 제3 법인 DMH Bank)가 파산한 경우:

(a) 해당 법인의 규제 당국(예: Labuan FSA)이 공식 지갑으로 파산 선언 트랜잭션을 전송;

(b) 해당 법인 컨트랙트의 isPaused 상태를 true로 변경하여 모든 거래 중단;

(c) 블록체인에 다음 정보를 포함하는 EntityBankrupt 이벤트를 기록:
  - entityName: 파산 법인명
  - jurisdiction: 관할권
  - licenseNumber: 라이선스 번호
  - bankruptcyReason: 파산 사유
  - timestamp: 파산 선언 시각;

(d) 다른 법인(제1, 제2 법인) 컨트랙트는 정상 운영 계속;

(e) 파산 법인의 고객 자금은 해당 관할권의 예금자 보호 제도(예: Labuan FSA 예금자 보호 기금)에 따라 처리되며, 다른 법인 고객 자금에는 영향 없음을 블록체인 이벤트로 명확히 기록;

(f) 화이트라벨 파트너십이 체결된 경우, 주체 법인(예: BLX CORE)이 대체 서비스 제공자를 즉시 지정할 수 있도록 긴급 파트너십 변경 프로세스를 실행;

을 자동으로 실행하는 단계를 더 포함하는,

것을 특징으로 하는 방법.

---

## 【도면의 간단한 설명】

[062] 본 발명을 첨부 도면을 참조하여 더욱 상세히 설명한다.

**도 1**: 본 발명의 다중 관할권 법인 분리 생태계 전체 구성도
- 3개 법인(BLX CORE, DMHB DLT, DMH Bank)이 각각 독립적인 스마트 컨트랙트 운영
- 라이선스 범위 검증 메커니즘 표시
- 화이트라벨 파트너십 연결 구조
- 자금 격리 + 데이터 인터페이스 구분

**도 2**: 라이선스 범위 검증 및 화이트라벨 파트너십 블록도
- checkLicenseScope modifier 작동 원리
- 허용 활동 vs 금지 활동 비트마스크 검증
- 금지 활동 시도 시 파트너십 위임 프로세스
- 사용자 고지 메커니즘

**도 3**: FSRA 2025 규제 준수 자동화 흐름도
- 토큰 발행 요청 수신
- LBMA 금 출처 검증
- 비환매형 확인
- KYC/AML 자동 검증
- FSRA 자동 보고

**도 4**: TRR-Pay 통합 구조 다이어그램
- BLX CORE: 토큰 발행 + 인터페이스 제공
- DMH Bank: 결제 실행 + 정산
- Railsr/Marqeta: 카드 발급
- 사용자 자금 흐름: 사용자 → DMH Bank (BLX CORE 경유 없음)

**도 5**: 외부 감사자 검증 프로세스
- 블록체인 이벤트 로그 조회
- 크로스 엔티티 호출 통계 집계
- 데이터 인터페이스 vs 자금 전송 구분
- 감사 보고서 자동 생성

---

## 【산업상 이용가능성】

[063] 본 발명은 블록체인 기반 금융 서비스를 제공하는 모든 기업에 적용 가능하며, 특히 다음 산업에서 즉시 활용 가능하다:

**1. 토큰 증권(STO) 발행사**
- 증권 발행, DAO 거버넌스, 배당 지급을 별도 법인으로 분리
- 각국 증권 규제 독립적으로 준수
- 예: BLX CORE (토큰 발행, ADGM) + BLX Dividend Co. (배당 지급, 케이맨)

**2. 암호화폐 거래소**
- 토큰 발행, 거래, 예금 업무를 별도 법인으로 분리
- 해킹 발생 시 피해 법인만 격리하여 다른 업무 계속
- 예: Exchange A (거래, 싱가포르) + Custody B (보관, 스위스)

**3. 무역금융 플랫폼 (TRR)**
- 신용장 발행, 환어음 거래, 무역보험을 별도 법인으로 분리
- 국제 무역 규제(ICC, WTO) 관할권별 대응
- 예: TRR Foundation (DAO, ADGM) + DMH Bank (정산, Labuan)

**4. 디지털 자산 은행**
- 예금, 대출, 투자 업무를 별도 법인으로 분리
- 바젤 III 자기자본 규제 효율적 대응
- 예: Digital Bank A (예금, Labuan) + Asset Manager B (투자, ADGM)

**5. 소비자 결제 서비스 (TRR-Pay)**
- 토큰 발행, 결제 실행, 카드 발급을 별도 법인/파트너로 분리
- 각 관할권의 PSP(Payment Service Provider) 규제 준수
- 예: BLX CORE (인터페이스) + DMH Bank (결제) + Railsr (카드)

[064] 본 발명은 특히 ADGM(아부다비), Labuan(말레이시아), 싱가포르, 스위스 등 블록체인 친화적 관할권에서 즉시 적용 가능하며, 각국 규제 당국의 승인을 받기에 유리한 구조를 제공한다.

---

## 【첨부 서류】

### 첨부 1: 관할권별 규제 요건 비교표 (2025년 기준)

|
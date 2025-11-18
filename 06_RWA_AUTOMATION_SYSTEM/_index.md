# RWA Automation System

**Real World Asset (RWA) 자동화 시스템** - 4계층 아키텍처 기반 블록체인 자동화 솔루션

## 📋 개요

이 시스템은 실물 자산(Real World Assets)의 데이터 수집, 트리거링, 크로스체인 자동화, 신뢰 검증을 통합한 종합 솔루션입니다.

## 🏗️ 시스템 아키텍처

### Layer 1: BLX Multi-RWA Feed
다중 RWA 데이터 피드 시스템으로, 다음 소스에서 데이터를 수집합니다:
- **Bloomberg Data** - 미국 국채 (30% 가중치)
- **Asset Manager** - 사모 신용 (20% 가중치)
- **LBMA** - 금 (50% 가중치)

**스마트 컨트랙트**: `Layer1_BLXMultiRWAFeed.sol`

### Layer 2: TLX Trigger System
LTV(Loan-to-Value) 기반 트리거 시스템:
- **목표 LTV**: 120%
- **트리거 LTV**: 125%
- **타임락**: 60일
- 자동 담보 가치 모니터링 및 트리거 활성화

**스마트 컨트랙트**: `Layer2_HTLXTrigger.sol`

### Layer 3: Automation & Cross-chain
자동화 및 크로스체인 통합:
- **Gelato Keeper**: 조건 모니터링 및 자동 실행
- **Axelar Bridge**: 다중 체인 동기화
- **목표 정산 시간**: 60초 이하

**스마트 컨트랙트**:
- `Layer3_GelatoAutomation.sol`
- `Layer3_AxelarBridge.sol`

### Layer 4: Trust Automation
신뢰 자동화 및 정산 시스템:
- **Proof of Trust**: 7개 오라클 합의 메커니즘
- **Audit Trail**: 불변 감사 로그
- **Rule Engine**: 컴플라이언스 규칙 엔진
- **Digital LC**: 디지털 신용장 정산

**스마트 컨트랙트**:
- `Layer4_ProofOfTrust.sol`
- `Layer4_AuditTrail.sol`
- `Layer4_RuleEngine.sol`
- `Layer4_DigitalLC.sol`

## 📂 디렉토리 구조

```
06_RWA_AUTOMATION_SYSTEM/
├── contracts/              # 스마트 컨트랙트
│   ├── Layer1_BLXMultiRWAFeed.sol
│   ├── Layer2_HTLXTrigger.sol
│   ├── Layer3_GelatoAutomation.sol
│   ├── Layer3_AxelarBridge.sol
│   ├── Layer4_ProofOfTrust.sol
│   ├── Layer4_AuditTrail.sol
│   ├── Layer4_RuleEngine.sol
│   └── Layer4_DigitalLC.sol
├── scripts/                # 배포 및 관리 스크립트
│   ├── deploy.js
│   ├── setup.js
│   └── monitor.js
├── docs/                   # 상세 문서
│   ├── architecture.md
│   ├── deployment-guide.md
│   ├── integration-guide.md
│   └── api-reference.md
├── config/                 # 설정 파일
│   ├── networks.json
│   ├── oracles.json
│   └── gelato-config.json
└── _index.md              # 이 파일
```

## 🚀 주요 기능

### 1. 실시간 RWA 데이터 수집
- 다중 소스 통합 (Bloomberg, Asset Manager, LBMA)
- 가중 평균 바스켓 가치 계산
- 가격 편차 검증

### 2. 자동 LTV 모니터링
- 실시간 담보 가치 추적
- 임계값 기반 트리거 활성화
- 60일 타임락 보호

### 3. 크로스체인 동기화
- Axelar를 통한 다중 체인 지원
- Ethereum, Polygon, Arbitrum, Optimism, Avalanche, BSC
- 60초 이하 정산 시간

### 4. 신뢰 검증
- 7개 오라클 합의 (5/7 임계값)
- 신뢰 점수 추적 및 업데이트
- 불변 감사 로그

### 5. 컴플라이언스
- 규칙 기반 평가 시스템
- 화이트리스트/블랙리스트 관리
- KYC/AML 통합

### 6. 디지털 신용장
- 자동 정산 시스템
- 문서 검증 워크플로우
- 컴플라이언스 통합

## 🔧 기술 스택

- **Solidity**: ^0.8.20
- **OpenZeppelin**: 보안 라이브러리
- **Gelato Network**: 자동화 인프라
- **Axelar**: 크로스체인 통신
- **Hardhat/Foundry**: 개발 프레임워크

## 📊 데이터 흐름

```
Bloomberg/AssetManager/LBMA → BLX Contract → LTV Calculator
                                                    ↓
                                            Trigger Logic
                                                    ↓
                                            HTLX Timelock
                                                    ↓
                                         Gelato Keeper
                                                    ↓
                                         Axelar Bridge
                                                    ↓
                                    Proof of Trust (7 Oracles)
                                                    ↓
                                         Audit Trail
                                                    ↓
                                         Rule Engine
                                                    ↓
                                         Digital LC Settlement
```

## 🔐 보안 기능

1. **Access Control**: 역할 기반 권한 관리
2. **ReentrancyGuard**: 재진입 공격 방지
3. **Pausable**: 긴급 정지 메커니즘
4. **Timelock**: 60일 지연 실행
5. **Multi-sig**: 다중 서명 지원 준비
6. **Audit Trail**: 모든 작업 기록

## 📈 성능 지표

- **정산 시간**: < 60초
- **오라클 합의**: 5/7 (71.4%)
- **가격 편차 허용**: 5%
- **신뢰 점수 임계값**: 80%
- **모니터링 간격**: 5분

## 🔗 통합 가이드

### 1. 오라클 등록
```javascript
await proofOfTrust.registerOracle(oracleAddress);
```

### 2. 데이터 제출
```javascript
await blxFeed.updateAssetPrice(assetType, price);
```

### 3. 대출 생성
```javascript
await htlxTrigger.createLoan(borrower, loanAmount);
```

### 4. 모니터링 작업 생성
```javascript
await gelatoAutomation.createMonitorTask(loanId);
```

### 5. LC 발행
```javascript
await digitalLC.issueLC(beneficiary, amount, currency, expiryDate, termsHash, autoSettle);
```

## 📚 추가 문서

- [아키텍처 상세 설명](./docs/architecture.md)
- [배포 가이드](./docs/deployment-guide.md)
- [통합 가이드](./docs/integration-guide.md)
- [API 레퍼런스](./docs/api-reference.md)

## 🧪 테스트

```bash
# 단위 테스트
npm run test

# 커버리지
npm run coverage

# 통합 테스트
npm run test:integration
```

## 🚀 배포

```bash
# 로컬 네트워크
npm run deploy:local

# 테스트넷
npm run deploy:testnet

# 메인넷
npm run deploy:mainnet
```

## 📞 지원

문의사항은 HTS DAO 팀에 연락하시기 바랍니다.

## 📄 라이센스

© HTS DAO 2025 - Private use only

---

**마지막 업데이트**: 2025-11-18
**버전**: 1.0.0
**작성자**: HTS DAO Technical Team

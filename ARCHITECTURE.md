# AFE Protocol 아키텍처

## 전체 구조

AFE Protocol은 4대 핵심 Pallet이 유기적으로 연동되는 구조입니다.

```
┌─────────────────────────────────────────────────────────┐
│                    AFE Protocol Runtime                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  👁️ Eyes (Oracle)  →  🧠 Brain (Risk)  →  ❤️ Heart       │
│       │                     │                   │         │
│   가격 피드              P_adj 계산          CS 계산      │
│   거버넌스              Circuit Breaker      대출 실행    │
│       │                     │                   │         │
│       └─────────────────────┼───────────────────┘         │
│                             ↓                             │
│                  🛡️ Shield (ZK Verification)             │
│                     영지식 증명 검증                       │
│                     Nullifier 추적                        │
└─────────────────────────────────────────────────────────┘
```

---

## 데이터 흐름

### 정상 대출 플로우

```
Oracle (Eyes) → Brain (Risk) → Shield (ZK) → Heart (Lending)
      │              │              │              │
   가격 조회       P_adj 계산     LTV 검증      대출 실행
```

### 위기 대응 플로우

```
가격 급락 감지 → Brain CB 발동 → Heart 청산 방지 단계 진입
      │                │                    │
  Oracle Alert    Circuit Breaker      3-Step Protection
```

---

## 4대 Pallet 상세

### 1. 🧠 Brain (pallet-risk-valuation)

**역할**: 시스템 전체의 리스크를 평가하고 위기 시 자동 개입

#### 핵심 기능

1. **P_adj (조정 가격) 계산**
   ```
   P_adj = P_market × (1 - Δ × k_panic)

   여기서:
   - P_market: Oracle에서 제공하는 시장 가격
   - Δ: 가격 변동성 (%)
   - k_panic: 공황 계수 (0.1 ~ 3.0)
   ```

2. **Circuit Breaker (서킷 브레이커)**
   - 조건: `Δ ≥ 30%` 또는 `급격한 가격 하락`
   - 효과: 청산 일시 중지, 대출 신규 중단
   - 복구: 가격 안정화 후 수동 재개

3. **리스크 점수 관리**
   - 자산별 리스크 가중치
   - 포트폴리오 전체 리스크 계산
   - 동적 담보 비율 조정 신호 생성

#### 스토리지

- `AdjustedPrices`: Map<AssetId, (Price, Timestamp)>
- `CircuitBreakerActive`: bool
- `RiskScores`: Map<AccountId, RiskScore>
- `PanicCoefficient`: u32 (0~3000, 소수점 3자리)

#### Extrinsics

- `update_adjusted_price(asset_id, delta, k_panic)`
- `trigger_circuit_breaker()`
- `reset_circuit_breaker()` (Root only)
- `calculate_risk_score(account_id)`

---

### 2. 👁️ Eyes (pallet-oracle-governance)

**역할**: 탈중앙화된 가격 피드 제공 및 거버넌스 관리

#### 핵심 기능

1. **가격 피드 검증**
   - 다중 Oracle 소스 집계
   - 이상치 제거 (중앙값 기반)
   - 최종 가격 확정 및 브로드캐스트

2. **거버넌스 투표**
   - Oracle 추가/제거
   - 시스템 파라미터 변경
   - 긴급 조치 승인

3. **데이터 품질 관리**
   - Oracle 신뢰도 점수
   - 지연 시간 모니터링
   - 자동 Oracle 제외 메커니즘

#### 스토리지

- `PriceFeeds`: Map<AssetId, Vec<(OracleId, Price, Timestamp)>>
- `OracleRegistry`: Map<OracleId, OracleMetadata>
- `GovernanceProposals`: Map<ProposalId, Proposal>
- `OracleTrustScores`: Map<OracleId, TrustScore>

#### Extrinsics

- `submit_price(asset_id, price)` (Oracle only)
- `register_oracle(oracle_id)` (Root only)
- `create_proposal(proposal_type, data)`
- `vote_on_proposal(proposal_id, vote)`

---

### 3. 🛡️ Shield (pallet-zk-verification)

**역할**: 프라이버시 보호하면서 대출 자격 증명

#### 핵심 기능

1. **LTV 영지식 증명**
   - 실제 담보 금액 노출 없이 LTV 충족 증명
   - Groth16 또는 Plonk 기반 증명 시스템

2. **Nullifier 추적**
   - 이중 사용 방지
   - 익명성 유지하면서 중복 방지

3. **KYC 영지식 증명**
   - 신원 정보 노출 없이 KYC 완료 증명
   - Merkle Tree 기반 멤버십 증명

#### 스토리지

- `VerificationKeys`: Map<ProofType, VerificationKey>
- `UsedNullifiers`: Map<Nullifier, bool>
- `ProofRequirements`: Map<LoanType, ProofRequirement>

#### Extrinsics

- `submit_ltv_proof(proof, public_inputs)`
- `submit_kyc_proof(proof, nullifier)`
- `verify_proof(proof_type, proof, public_inputs)`
- `update_verification_key(proof_type, vk)` (Root only)

---

### 4. ❤️ Heart (pallet-stablecoin-lending)

**역할**: 실제 대출 실행 및 담보 관리

#### 핵심 기능

1. **CS (Circuit Score) 계산**
   ```
   CS = 100 - (Δ × 2) - (CB_active ? 50 : 0)

   여기서:
   - Δ: Brain에서 계산한 가격 변동성
   - CB_active: Circuit Breaker 활성화 여부
   ```

2. **CR_dynamic (동적 담보 비율) 결정**
   ```
   CR_dynamic = CR_base + (100 - CS) / 10

   예시:
   - CS = 90 → CR_dynamic = 150% + 1% = 151%
   - CS = 50 → CR_dynamic = 150% + 5% = 155%
   - CS = 0 → CR_dynamic = 150% + 10% = 160%
   ```

3. **3단계 청산 방지 메커니즘**

   **단계 1: Warning (CS 50~70)**
   - 사용자에게 경고 알림
   - 추가 담보 예치 권장

   **단계 2: Partial Liquidation (CS 30~49)**
   - 부분 청산 (담보의 30% 매각)
   - LTV를 안전 수준으로 회복

   **단계 3: Emergency Pause (CS < 30)**
   - Circuit Breaker 발동
   - 전체 청산 중지
   - 시장 안정화 대기

#### 스토리지

- `Loans`: Map<LoanId, LoanDetails>
- `CollateralRatios`: Map<AssetId, CR_dynamic>
- `CircuitScores`: Map<AssetId, CS>
- `TotalLent`: Balance
- `TotalCollateral`: Map<AssetId, Balance>

#### Extrinsics

- `request_loan(collateral_amount, loan_amount, zk_proof)`
- `add_collateral(loan_id, amount)`
- `repay_loan(loan_id, amount)`
- `liquidate_loan(loan_id)` (단계별 자동 실행)
- `update_circuit_score(asset_id)`

---

## 통합 시나리오

### 시나리오 1: 정상 대출 실행

```
1. 사용자가 Heart에 대출 요청
   └─> Heart가 Shield에 LTV 증명 요청

2. Shield가 ZK 증명 검증
   └─> 검증 성공 시 Heart로 승인 전달

3. Heart가 Brain에 P_adj 요청
   └─> Brain이 Oracle에서 가격 조회
   └─> P_adj 계산 후 Heart로 전달

4. Heart가 CS 계산
   └─> CR_dynamic 결정
   └─> 대출 실행
```

### 시나리오 2: 위기 대응 (가격 급락)

```
1. Oracle이 가격 급락 감지 (예: BTC 30% 하락)
   └─> Brain에 가격 업데이트 전달

2. Brain이 Circuit Breaker 발동
   └─> CB_active = true
   └─> 모든 Pallet에 CB 상태 브로드캐스트

3. Heart가 CS 재계산
   └─> CS = 100 - (30 × 2) - 50 = -10 → 0 (최소값)
   └─> 3단계 Emergency Pause 진입
   └─> 모든 청산 중지

4. 시장 안정화 대기
   └─> Brain이 가격 안정 확인
   └─> Root가 CB 해제
   └─> Heart가 정상 운영 재개
```

### 시나리오 3: 부분 청산 (단계 2)

```
1. 가격 하락으로 LTV 상승
   └─> Heart가 CS 계산: CS = 35 (단계 2 진입)

2. Heart가 부분 청산 실행
   └─> 담보의 30% 매각
   └─> 매각 대금으로 부채 감소

3. LTV 안전 수준 회복
   └─> CS = 60으로 상승
   └─> 단계 1 (Warning)으로 전환
   └─> 사용자에게 추가 담보 권장
```

---

## 보안 고려사항

### 1. Oracle 공격 방지
- 다중 Oracle 소스 사용
- 이상치 제거 알고리즘
- Oracle 신뢰도 점수 시스템

### 2. ZK 증명 검증
- 검증 키 업데이트 메커니즘
- Nullifier 이중 사용 방지
- Proof 만료 시간 설정

### 3. Circuit Breaker 남용 방지
- Root 권한만 수동 발동 가능
- 자동 발동은 명확한 조건 충족 시만
- 감사 로그 기록

### 4. 재진입 공격 방지
- 모든 외부 호출 전 상태 업데이트
- Mutex 패턴 적용
- 재진입 가드 사용

---

## 성능 최적화

### 1. 스토리지 최적화
- 자주 접근하는 데이터는 캐시 활용
- 불필요한 Map 탐색 최소화
- 배치 업데이트 사용

### 2. 계산 최적화
- P_adj 계산은 가격 변동 시만 수행
- CS 계산은 대출 요청 시만 수행
- 복잡한 증명 검증은 Off-chain Worker 활용

### 3. 가스 비용 최적화
- 불필요한 이벤트 제거
- 스토리지 읽기/쓰기 최소화
- 배치 작업 우선 사용

---

## 향후 확장 계획

### 1. 다중 체인 지원
- Cross-chain Oracle 통합
- Cross-chain 대출 프로토콜

### 2. 고급 리스크 모델
- 머신러닝 기반 리스크 예측
- 실시간 시장 센티먼트 분석

### 3. 거버넌스 강화
- DAO 기반 파라미터 조정
- 커뮤니티 제안 시스템

---

## 참고 자료

- [Substrate Documentation](https://docs.substrate.io/)
- [FRAME Pallet Development](https://docs.substrate.io/reference/frame-pallets/)
- [Zero-Knowledge Proofs](https://z.cash/technology/zksnarks/)
- [Circuit Breaker Patterns](https://martinfowler.com/bliki/CircuitBreaker.html)

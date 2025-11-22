# AFE Protocol

**Substrate 기반 분산형 금융 프로토콜 - 4대 핵심 Pallet 통합**

---

## 아키텍처

### 4대 핵심 Pallet

- 🧠 **Brain (Risk Valuation)** - 리스크 평가 및 Circuit Breaker
- 👁️ **Eyes (Oracle Governance)** - 가격 피드 및 거버넌스
- 🛡️ **Shield (ZK Verification)** - 영지식 증명 검증
- ❤️ **Heart (Stablecoin Lending)** - 스테이블코인 대출

---

## 빠른 시작

### 빌드

```bash
cargo build --release
```

### 테스트

```bash
cargo test --all
```

### 노드 실행

```bash
./target/release/afe-node --dev
```

---

## 프로젝트 구조

```
AFE Protocol/
├── pallets/
│   ├── risk-valuation/       # 🧠 Brain: P_adj 계산, Circuit Breaker
│   ├── oracle-governance/    # 👁️ Eyes: 가격 피드, 거버넌스
│   ├── zk-verification/      # 🛡️ Shield: ZK 증명 검증
│   └── stablecoin-lending/   # ❤️ Heart: CS 계산, 대출 관리
├── runtime/                  # 4대 Pallet 통합
├── tests/integration/        # E2E 통합 테스트
└── docs/                     # 프로젝트 문서
```

---

## 주요 기능

### 1. 리스크 관리 (Brain)
- 동적 가격 조정 (P_adj)
- Circuit Breaker 자동 발동
- 3단계 위기 대응 시스템

### 2. Oracle 거버넌스 (Eyes)
- 탈중앙화 가격 피드
- 데이터 품질 검증
- 거버넌스 투표 시스템

### 3. ZK 검증 (Shield)
- 프라이버시 보호 LTV 증명
- Nullifier 기반 이중 사용 방지
- KYC 영지식 증명

### 4. 스테이블코인 대출 (Heart)
- CS (Circuit Score) 기반 대출
- CR_dynamic 담보 비율 조정
- 3단계 청산 방지 메커니즘

---

## 문서

- [아키텍처 가이드](./ARCHITECTURE.md) - 시스템 설계 상세
- [개발팀 인계 문서](./docs/HANDOVER.md) - 프로덕션 준비 가이드
- [설치 가이드](./docs/INSTALL.md) - 개발 환경 설정
- [API 문서](./docs/API.md) - Pallet 인터페이스

---

## 기술 스택

- **Substrate Framework** - Polkadot SDK v1.0.0
- **Rust** - Edition 2021
- **FRAME Pallets** - 커스텀 비즈니스 로직
- **ZK Proofs** - 영지식 증명 통합

---

## 개발 로드맵

### ✅ 완성 (현재)
- 4대 Pallet 완전 구현
- Runtime 통합
- E2E 테스트 스위트
- 전체 문서화

### 🚧 다음 단계
- 성능 최적화
- 보안 감사
- 메인넷 배포 준비

---

## 기여 가이드

본 프로젝트는 개발팀 인계를 위해 준비되었습니다.

자세한 내용은 [HANDOVER.md](./docs/HANDOVER.md)를 참조하세요.

---

## 라이선스

Apache-2.0

---

## 연락처

- **프로젝트 저장소**: https://github.com/Geserkhan/HTS_Global_Intelligence_Base
- **이슈 트래커**: GitHub Issues

---

## 감사의 말

본 프로젝트는 Substrate 프레임워크와 Polkadot 생태계를 기반으로 구축되었습니다.

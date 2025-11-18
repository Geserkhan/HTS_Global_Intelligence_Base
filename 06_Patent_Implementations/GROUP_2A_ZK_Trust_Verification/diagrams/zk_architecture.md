# GROUP 2A: Zero-Knowledge Trust Verification Engine - Architecture Diagrams

## 1. ZK Circuit Architecture

```mermaid
graph TB
    subgraph "PRIVATE INPUTS (Witness)"
        W1["KYC Score<br/>(Hidden)"]
        W2["AML Score<br/>(Hidden)"]
        W3["Credit Score<br/>(Hidden)"]
        W4["Reputation Score<br/>(Hidden)"]
        W5["Issuer Signatures<br/>(Hidden)"]
    end

    subgraph "WITNESS GENERATION"
        W1 --> GEN["Witness Generator<br/>Contract"]
        W2 --> GEN
        W3 --> GEN
        W4 --> GEN
        W5 --> GEN
        GEN --> COMMIT["Pedersen Commitment<br/>H = hash(witness + random)"]
    end

    subgraph "ZK CIRCUIT (Circom)"
        COMMIT --> CIRCUIT["Trust Score Circuit"]
        CIRCUIT --> C1["Constraint 1:<br/>Score ≥ 70"]
        CIRCUIT --> C2["Constraint 2:<br/>Valid Signatures"]
        CIRCUIT --> C3["Constraint 3:<br/>Fresh Timestamp"]
        CIRCUIT --> C4["Constraint 4:<br/>Merkle Proof Valid"]
        C1 --> PROOF["Generate Proof<br/>(Groth16)"]
        C2 --> PROOF
        C3 --> PROOF
        C4 --> PROOF
    end

    subgraph "PUBLIC OUTPUTS"
        PROOF --> OUT1["Trust Score Hash"]
        PROOF --> OUT2["User Address"]
        PROOF --> OUT3["Timestamp"]
        PROOF --> OUT4["Proof Valid: TRUE"]
    end

    subgraph "ON-CHAIN VERIFICATION"
        OUT1 --> VERIFY["Groth16 Verifier<br/>Contract"]
        OUT2 --> VERIFY
        OUT3 --> VERIFY
        OUT4 --> VERIFY
        VERIFY --> RESULT["✓ Proof Accepted<br/>Trust Score Updated"]
    end

    style W1 fill:#FF6B6B,stroke:#333,color:#fff
    style W2 fill:#FF6B6B,stroke:#333,color:#fff
    style W3 fill:#FF6B6B,stroke:#333,color:#fff
    style W4 fill:#FF6B6B,stroke:#333,color:#fff
    style W5 fill:#FF6B6B,stroke:#333,color:#fff
    style COMMIT fill:#4ECDC4,stroke:#333,color:#fff
    style CIRCUIT fill:#FFE66D,stroke:#333,color:#000
    style PROOF fill:#95E1D3,stroke:#333,color:#000
    style VERIFY fill:#4A90E2,stroke:#333,color:#fff
    style RESULT fill:#50C878,stroke:#333,color:#fff
```

## 2. Witness Generation & Validation Process

```mermaid
sequenceDiagram
    participant User
    participant WitnessGen as Witness Generator
    participant Issuer as Credential Issuer
    participant Circuit as ZK Circuit (Off-chain)
    participant Verifier as Groth16 Verifier
    participant TrustContract as ZK Trust Verifier

    Note over User,TrustContract: Phase 1: Credential Collection

    User->>Issuer: Request KYC Credential
    Issuer->>Issuer: Verify Identity
    Issuer->>User: Issue Signed Credential (score=85)

    User->>Issuer: Request AML Credential
    Issuer->>User: Issue Signed Credential (score=90)

    User->>Issuer: Request Credit Score
    Issuer->>User: Issue Signed Credential (score=75)

    Note over User,TrustContract: Phase 2: Witness Commitment

    User->>WitnessGen: addCredential(KYC, 85, issuerHash)
    WitnessGen->>WitnessGen: Store Credential

    User->>WitnessGen: addCredential(AML, 90, issuerHash)
    User->>WitnessGen: addCredential(CREDIT, 75, issuerHash)

    User->>WitnessGen: generateAggregateWitness([KYC, AML, CREDIT])
    WitnessGen->>WitnessGen: Compute Average Score = 83
    WitnessGen->>WitnessGen: Build Merkle Tree
    WitnessGen->>WitnessGen: commitment = hash(user, scores, merkleRoot)
    WitnessGen-->>User: Return commitment

    User->>WitnessGen: generateWitness(user, privateData, merkleRoot)
    WitnessGen->>WitnessGen: Create Witness Commitment
    WitnessGen-->>User: witnessCommitment

    Note over User,TrustContract: Phase 3: Proof Generation (Off-chain)

    User->>Circuit: Generate Proof
    Note over Circuit: Private Inputs:<br/>- KYC: 85<br/>- AML: 90<br/>- Credit: 75<br/>- Signatures
    Note over Circuit: Public Inputs:<br/>- User Address<br/>- Commitment<br/>- Average Score: 83<br/>- Timestamp

    Circuit->>Circuit: Verify Constraints:<br/>✓ Score ≥ 70<br/>✓ Signatures Valid<br/>✓ Merkle Proof Valid
    Circuit-->>User: zkProof (a, b, c)

    Note over User,TrustContract: Phase 4: On-Chain Verification

    User->>TrustContract: verifyProof(circuitId, proof, publicInputs, 83)
    TrustContract->>TrustContract: Check proof not used
    TrustContract->>Verifier: verifyProof(a, b, c, publicInputs)

    Verifier->>Verifier: Pairing Check:<br/>e(A,B) = e(α,β)·e(C,δ)·e(vk_x,γ)
    Verifier-->>TrustContract: true

    TrustContract->>TrustContract: Mark proof as used
    TrustContract->>TrustContract: Update Trust Score
    TrustContract-->>User: ✓ Trust Score Verified (83)

    Note over User,TrustContract: Score stored without revealing private credentials!
```

## 3. Privacy-Preserving Verification Flow

```mermaid
graph LR
    subgraph "USER SIDE (Private)"
        U1["Private Credentials:<br/>• KYC: 85<br/>• AML: 90<br/>• Credit: 75<br/>• Signatures"]
        U2["Generate Witness"]
        U3["Compute Commitment<br/>C = hash(credentials)"]
        U4["Build Merkle Tree"]
        U5["Generate ZK Proof"]

        U1 --> U2
        U2 --> U3
        U3 --> U4
        U4 --> U5
    end

    subgraph "BLOCKCHAIN (Public)"
        B1["Witness Commitment<br/>0x7a3f..."]
        B2["Public Inputs:<br/>• Address<br/>• Timestamp<br/>• Score: 83"]
        B3["ZK Proof<br/>(a, b, c)"]
        B4["Verifier Contract"]
        B5["Trust Score Storage"]

        B1 --> B4
        B2 --> B4
        B3 --> B4
        B4 --> B5
    end

    U5 -->|Submit Proof| B3
    U3 -->|Publish Commitment| B1

    B5 --> RESULT["✓ Trust Score: 83<br/>✗ Credentials: HIDDEN"]

    style U1 fill:#FF6B6B,stroke:#333,color:#fff
    style U2 fill:#FF6B6B,stroke:#333,color:#fff
    style U3 fill:#FFE66D,stroke:#333,color:#000
    style U4 fill:#FFE66D,stroke:#333,color:#000
    style U5 fill:#95E1D3,stroke:#333,color:#000
    style B4 fill:#4A90E2,stroke:#333,color:#fff
    style B5 fill:#7B68EE,stroke:#333,color:#fff
    style RESULT fill:#50C878,stroke:#333,color:#fff
```

## 4. Anti-Fraud Mechanism

```mermaid
graph TB
    subgraph "PROOF SUBMISSION"
        P1["User Submits Proof"]
        P2["Generate Proof Hash"]
        P3["Check Used Proofs Map"]
    end

    subgraph "VALIDATION CHECKS"
        V1["Proof Hash Unique?"]
        V2["Timestamp Fresh?<br/>(within 30 days)"]
        V3["Score ≥ Threshold?"]
        V4["Merkle Root Valid?"]
        V5["Pairing Check Passed?"]
    end

    subgraph "FRAUD DETECTION"
        F1["Replay Attack?"]
        F2["Expired Proof?"]
        F3["Invalid Score?"]
        F4["Forged Credentials?"]
        F5["Pairing Failed?"]
    end

    subgraph "OUTCOME"
        O1["✓ Accept Proof<br/>Update Trust Score"]
        O2["✗ Reject Proof<br/>Revert Transaction"]
    end

    P1 --> P2
    P2 --> P3
    P3 --> V1

    V1 -->|NO| F1
    V1 -->|YES| V2
    V2 -->|NO| F2
    V2 -->|YES| V3
    V3 -->|NO| F3
    V3 -->|YES| V4
    V4 -->|NO| F4
    V4 -->|YES| V5
    V5 -->|NO| F5
    V5 -->|YES| O1

    F1 --> O2
    F2 --> O2
    F3 --> O2
    F4 --> O2
    F5 --> O2

    style P1 fill:#4ECDC4,stroke:#333,color:#fff
    style V1 fill:#FFE66D,stroke:#333,color:#000
    style V2 fill:#FFE66D,stroke:#333,color:#000
    style V3 fill:#FFE66D,stroke:#333,color:#000
    style V4 fill:#FFE66D,stroke:#333,color:#000
    style V5 fill:#FFE66D,stroke:#333,color:#000
    style F1 fill:#FF6B6B,stroke:#333,color:#fff
    style F2 fill:#FF6B6B,stroke:#333,color:#fff
    style F3 fill:#FF6B6B,stroke:#333,color:#fff
    style F4 fill:#FF6B6B,stroke:#333,color:#fff
    style F5 fill:#FF6B6B,stroke:#333,color:#fff
    style O1 fill:#50C878,stroke:#333,color:#fff
    style O2 fill:#FF6B6B,stroke:#333,color:#fff
```

## 5. Batch Verification Optimization

```mermaid
graph LR
    subgraph "MULTIPLE USERS"
        U1["User 1<br/>Proof + Score"]
        U2["User 2<br/>Proof + Score"]
        U3["User 3<br/>Proof + Score"]
        U4["User 4<br/>Proof + Score"]
    end

    subgraph "BATCH PROCESSING"
        BATCH["Batch Verifier"]
        AGGREGATE["Aggregate Proofs"]
        PARALLEL["Parallel Verification"]
    end

    subgraph "GAS OPTIMIZATION"
        GAS1["Single TX<br/>vs 4 TXs"]
        GAS2["~60% Gas Savings"]
    end

    subgraph "RESULTS"
        R1["User 1: ✓ Score 85"]
        R2["User 2: ✓ Score 90"]
        R3["User 3: ✓ Score 75"]
        R4["User 4: ✓ Score 88"]
    end

    U1 --> BATCH
    U2 --> BATCH
    U3 --> BATCH
    U4 --> BATCH

    BATCH --> AGGREGATE
    AGGREGATE --> PARALLEL
    PARALLEL --> GAS1
    GAS1 --> GAS2

    PARALLEL --> R1
    PARALLEL --> R2
    PARALLEL --> R3
    PARALLEL --> R4

    style BATCH fill:#4A90E2,stroke:#333,color:#fff
    style PARALLEL fill:#7B68EE,stroke:#333,color:#fff
    style GAS2 fill:#50C878,stroke:#333,color:#fff
```

## 6. Trust Score Lifecycle

```mermaid
stateDiagram-v2
    [*] --> NoScore: New User

    NoScore --> Pending: Submit Credentials
    Pending --> WitnessGeneration: Add Credentials
    WitnessGeneration --> ProofGeneration: Commitment Created
    ProofGeneration --> Verification: Generate ZK Proof

    Verification --> Valid: Proof Verified
    Verification --> Invalid: Proof Failed

    Valid --> Active: Score Stored
    Invalid --> [*]: Rejected

    Active --> Expired: 30 Days Passed
    Active --> Invalidated: Fraud Detected
    Active --> Updated: New Proof Submitted

    Expired --> WitnessGeneration: Re-verify
    Invalidated --> [*]
    Updated --> Verification

    Active --> [*]: User Exit
```

## 7. Contract Interaction Flow

```mermaid
graph TB
    subgraph "SMART CONTRACTS"
        SC1["WitnessGenerator.sol"]
        SC2["Groth16Verifier.sol"]
        SC3["ZKTrustVerifier.sol"]
    end

    subgraph "STEP 1: Credential Management"
        S1A["addCredential()"]
        S1B["generateAggregateWitness()"]
        S1C["generateWitness()"]
    end

    subgraph "STEP 2: Off-Chain Proof Generation"
        S2A["Compute Witness"]
        S2B["Generate Groth16 Proof"]
        S2C["Export Proof (a,b,c)"]
    end

    subgraph "STEP 3: On-Chain Verification"
        S3A["verifyProof() → Groth16"]
        S3B["Pairing Check"]
        S3C["Update Trust Score"]
    end

    SC1 --> S1A
    SC1 --> S1B
    SC1 --> S1C

    S1C --> S2A
    S2A --> S2B
    S2B --> S2C

    S2C --> S3A
    SC2 --> S3A
    S3A --> S3B
    S3B --> S3C
    SC3 --> S3C

    style SC1 fill:#FFE66D,stroke:#333,color:#000
    style SC2 fill:#95E1D3,stroke:#333,color:#000
    style SC3 fill:#4A90E2,stroke:#333,color:#fff
    style S3C fill:#50C878,stroke:#333,color:#fff
```

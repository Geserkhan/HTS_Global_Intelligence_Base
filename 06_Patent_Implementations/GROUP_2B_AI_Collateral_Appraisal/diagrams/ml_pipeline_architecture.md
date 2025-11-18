# GROUP 2B: AI-Based Collateral Auto-Appraisal System - Architecture Diagrams

## 1. ML Pipeline Architecture

```mermaid
graph TB
    subgraph "DATA INGESTION"
        D1["Chainlink Oracle<br/>Price Data"]
        D2["DEX Liquidity<br/>Pools"]
        D3["On-Chain Metrics<br/>(Volume, Holders)"]
        D4["Asset Metadata<br/>(Verified, Age)"]
    end

    subgraph "FEATURE ENGINEERING"
        D1 --> FE["FeatureEngineering<br/>Contract"]
        D2 --> FE
        D3 --> FE
        D4 --> FE
        FE --> F1["Price (normalized)"]
        FE --> F2["Volume 24h"]
        FE --> F3["Liquidity"]
        FE --> F4["Volatility Index"]
        FE --> F5["Market Cap"]
        FE --> F6["Holder Count"]
        FE --> F7["Asset Age"]
        FE --> F8["Supply Ratio"]
        FE --> F9["Price Change 24h"]
    end

    subgraph "FEATURE VECTOR"
        F1 --> VECTOR["Feature Vector<br/>[9 features]"]
        F2 --> VECTOR
        F3 --> VECTOR
        F4 --> VECTOR
        F5 --> VECTOR
        F6 --> VECTOR
        F7 --> VECTOR
        F8 --> VECTOR
        F9 --> VECTOR
    end

    subgraph "MODEL ORCHESTRATION"
        VECTOR --> ML["ML Oracle"]
        ML --> WORKER["ML Worker<br/>(Off-chain)"]
        WORKER --> MODEL["Gradient Boosting<br/>Model (XGBoost)"]
        MODEL --> PRED["Prediction:<br/>• Value<br/>• Confidence<br/>• Risk"]
    end

    subgraph "RISK POLICY"
        PRED --> POLICY["Risk Policy<br/>Validator"]
        POLICY --> CHECK1["Confidence ≥ 70?"]
        POLICY --> CHECK2["Risk Score ≤ 80?"]
        POLICY --> CHECK3["LTV Valid?"]
    end

    subgraph "OUTPUT"
        CHECK1 --> RESULT["Appraisal Result"]
        CHECK2 --> RESULT
        CHECK3 --> RESULT
        RESULT --> STORE["Store in<br/>AICollateralAppraisal"]
        STORE --> FINAL["✓ Collateral Approved<br/>Max Borrow: $X"]
    end

    style FE fill:#FFE66D,stroke:#333,color:#000
    style VECTOR fill:#95E1D3,stroke:#333,color:#000
    style MODEL fill:#4A90E2,stroke:#333,color:#fff
    style PRED fill:#7B68EE,stroke:#333,color:#fff
    style FINAL fill:#50C878,stroke:#333,color:#fff
```

## 2. Data Ingestion → Feature Engineering → Model Orchestration Flow

```mermaid
sequenceDiagram
    participant User
    participant Appraisal as AICollateralAppraisal
    participant Features as FeatureEngineering
    participant Chainlink as Chainlink Oracle
    participant Oracle as ML Oracle
    participant Worker as ML Worker (Off-chain)
    participant Model as ML Model

    Note over User,Model: Phase 1: Data Collection

    User->>Appraisal: requestAppraisal(asset, tokenId, type)
    Appraisal->>Appraisal: Generate requestId
    Appraisal-->>User: requestId

    Appraisal->>Features: extractFeatures(asset)

    Features->>Chainlink: latestRoundData()
    Chainlink-->>Features: price, timestamp, decimals

    Features->>Features: Fetch liquidity from DEX
    Features->>Features: Fetch on-chain metrics
    Features->>Features: Build feature vector

    Note over Features: Features Extracted:<br/>Price, Volume, Liquidity,<br/>Volatility, Market Cap,<br/>Holders, Age, etc.

    Features-->>Appraisal: featureVector[9]

    Note over User,Model: Phase 2: ML Inference

    Appraisal->>Oracle: createJob(modelHash, featureVector)
    Oracle->>Oracle: jobId++
    Oracle-->>Appraisal: jobId

    Worker->>Oracle: claimJob(jobId)
    Oracle->>Oracle: Assign job to worker
    Oracle-->>Worker: Job assigned

    Worker->>Worker: Decode feature vector
    Worker->>Model: predict(features)

    Note over Model: ML Model Processing:<br/>1. Feature normalization<br/>2. Tree traversal<br/>3. Ensemble prediction<br/>4. Confidence calibration

    Model-->>Worker: {value, confidence, risk}

    Worker->>Oracle: submitResult(jobId, prediction)
    Oracle->>Oracle: Validate worker
    Oracle->>Worker: Transfer reward
    Oracle-->>Appraisal: Result available

    Note over User,Model: Phase 3: Validation & Storage

    Appraisal->>Oracle: getPrediction(jobId)
    Oracle-->>Appraisal: {value: $5000, conf: 85, risk: 45}

    Appraisal->>Appraisal: Check risk policy:<br/>✓ confidence >= 70<br/>✓ risk <= 80<br/>✓ Calculate LTV

    Appraisal->>Appraisal: Store appraisal:<br/>value=$5000, LTV=75%

    Appraisal-->>User: ✓ Appraisal complete<br/>Max borrow: $3750

    Note over User,Model: User can now use asset as collateral!
```

## 3. Feature Engineering Pipeline

```mermaid
graph LR
    subgraph "RAW DATA SOURCES"
        R1["Price Oracle<br/>$45.50"]
        R2["DEX Pool<br/>$2.5M liquidity"]
        R3["Token Contract<br/>10,000 holders"]
        R4["Historical Data<br/>30-day volatility"]
    end

    subgraph "DATA NORMALIZATION"
        R1 --> N1["Normalize Price<br/>→ 45.5e18"]
        R2 --> N2["Log Transform<br/>→ ln(2500000)"]
        R3 --> N3["Scale Holders<br/>→ 10000/100000"]
        R4 --> N4["Volatility Index<br/>→ 0-100 scale"]
    end

    subgraph "FEATURE TRANSFORMATION"
        N1 --> T1["Price Features:<br/>• Current<br/>• 24h change<br/>• Moving avg"]
        N2 --> T2["Liquidity Features:<br/>• Total<br/>• Depth<br/>• Utilization"]
        N3 --> T3["Social Features:<br/>• Holder count<br/>• Distribution<br/>• Velocity"]
        N4 --> T4["Risk Features:<br/>• Volatility<br/>• Beta<br/>• Sharpe ratio"]
    end

    subgraph "FEATURE VECTOR"
        T1 --> FV["Feature Vector<br/>[f1, f2, ..., f9]"]
        T2 --> FV
        T3 --> FV
        T4 --> FV
    end

    subgraph "ENCODING"
        FV --> ENC["ABI Encode<br/>for ML Oracle"]
    end

    style N1 fill:#FFE66D,stroke:#333,color:#000
    style N2 fill:#FFE66D,stroke:#333,color:#000
    style N3 fill:#FFE66D,stroke:#333,color:#000
    style N4 fill:#FFE66D,stroke:#333,color:#000
    style FV fill:#4A90E2,stroke:#333,color:#fff
    style ENC fill:#50C878,stroke:#333,color:#fff
```

## 4. ML Worker Reputation System

```mermaid
graph TB
    subgraph "WORKER REGISTRATION"
        W1["New Worker"]
        W2["Stake 1000 ETH"]
        W3["Register Models"]
        W4["Initial Reputation: 50"]
    end

    subgraph "JOB EXECUTION"
        J1["Claim Job"]
        J2["Run Inference"]
        J3["Submit Result"]
    end

    subgraph "VALIDATION"
        V1{"Result Valid?"}
        V2["Accuracy Check"]
        V3["Latency Check"]
    end

    subgraph "REPUTATION UPDATE"
        S1["✓ Success"]
        S2["✗ Failure"]
        S3["Reputation +2"]
        S4["Reputation -5"]
        S5["Slash Stake 10%"]
    end

    subgraph "WORKER STATUS"
        ST1["High Reputation<br/>(80+)"]
        ST2["Medium Reputation<br/>(50-80)"]
        ST3["Low Reputation<br/>(&lt;50)"]
        ST4["⚠️ Deactivated"]
    end

    W1 --> W2
    W2 --> W3
    W3 --> W4
    W4 --> J1

    J1 --> J2
    J2 --> J3
    J3 --> V1

    V1 -->|YES| V2
    V1 -->|NO| S2
    V2 -->|PASS| S1
    V2 -->|FAIL| S2

    S1 --> S3
    S2 --> S4
    S2 --> S5

    S3 --> ST1
    S3 --> ST2
    S4 --> ST3
    S5 --> ST4

    style S1 fill:#50C878,stroke:#333,color:#fff
    style S2 fill:#FF6B6B,stroke:#333,color:#fff
    style ST1 fill:#50C878,stroke:#333,color:#fff
    style ST4 fill:#FF6B6B,stroke:#333,color:#fff
```

## 5. Risk Policy Validation

```mermaid
graph TB
    subgraph "ML PREDICTION OUTPUT"
        P1["Predicted Value:<br/>$5,000"]
        P2["Confidence Score:<br/>85/100"]
        P3["Risk Score:<br/>45/100"]
    end

    subgraph "ASSET TYPE POLICY"
        AT{"Asset Type?"}
        AT -->|ERC20| POL1["Policy:<br/>LTV: 75%<br/>Min Conf: 70<br/>Max Risk: 60"]
        AT -->|ERC721| POL2["Policy:<br/>LTV: 50%<br/>Min Conf: 75<br/>Max Risk: 70"]
        AT -->|RWA| POL3["Policy:<br/>LTV: 60%<br/>Min Conf: 80<br/>Max Risk: 50"]
    end

    subgraph "VALIDATION CHECKS"
        POL1 --> C1["Confidence ≥ 70?"]
        POL2 --> C1
        POL3 --> C1
        C1 -->|YES| C2["Risk ≤ Max?"]
        C1 -->|NO| REJECT
        C2 -->|YES| C3["Price Fresh?<br/>(&lt;24h)"]
        C2 -->|NO| REJECT
        C3 -->|YES| C4["Liquidity Sufficient?"]
        C3 -->|NO| REJECT
        C4 -->|YES| APPROVE
        C4 -->|NO| REJECT
    end

    subgraph "LTV CALCULATION"
        APPROVE --> LTV["Calculate Max Borrow"]
        LTV --> CALC["maxBorrow =<br/>value × LTV%"]
        CALC --> EXAMPLE["Example:<br/>$5000 × 75% = $3750"]
    end

    subgraph "RESULT"
        EXAMPLE --> FINAL["✓ Approved<br/>Max Borrow: $3,750"]
        REJECT["✗ Rejected<br/>Appraisal Failed"]
    end

    P1 --> AT
    P2 --> AT
    P3 --> AT

    style APPROVE fill:#50C878,stroke:#333,color:#fff
    style REJECT fill:#FF6B6B,stroke:#333,color:#fff
    style FINAL fill:#4A90E2,stroke:#333,color:#fff
```

## 6. Complete System Flow

```mermaid
graph TB
    START["User Deposits Collateral"] --> REQ["Request Appraisal"]
    REQ --> FEAT["Extract Features"]

    FEAT --> FEAT1["Price Data"]
    FEAT --> FEAT2["Market Data"]
    FEAT --> FEAT3["Social Data"]

    FEAT1 --> ENCODE["Encode Feature Vector"]
    FEAT2 --> ENCODE
    FEAT3 --> ENCODE

    ENCODE --> JOB["Create ML Job"]
    JOB --> ASSIGN["Assign to Worker"]
    ASSIGN --> INFER["Run ML Inference"]

    INFER --> PREDICT["Generate Prediction"]
    PREDICT --> SUBMIT["Submit Result"]

    SUBMIT --> VALIDATE["Validate Prediction"]
    VALIDATE --> POLICY["Check Risk Policy"]

    POLICY -->|PASS| APPROVE["Approve Collateral"]
    POLICY -->|FAIL| DENY["Reject Collateral"]

    APPROVE --> CALC["Calculate LTV"]
    CALC --> STORE["Store Appraisal"]
    STORE --> BORROW["Enable Borrowing"]

    DENY --> NOTIFY["Notify User"]
    NOTIFY --> END["End"]

    BORROW --> LOAN["Issue Loan"]
    LOAN --> MONITOR["Monitor Collateral"]
    MONITOR --> REAPPRAISE{"Value Changed<br/>>10%?"}
    REAPPRAISE -->|YES| REQ
    REAPPRAISE -->|NO| MONITOR

    style START fill:#4ECDC4,stroke:#333,color:#fff
    style INFER fill:#4A90E2,stroke:#333,color:#fff
    style APPROVE fill:#50C878,stroke:#333,color:#fff
    style DENY fill:#FF6B6B,stroke:#333,color:#fff
    style LOAN fill:#7B68EE,stroke:#333,color:#fff
```

## 7. ML Model Architecture (XGBoost)

```mermaid
graph TB
    subgraph "INPUT LAYER"
        I1["Feature 1: Price"]
        I2["Feature 2: Volume"]
        I3["Feature 3: Liquidity"]
        I4["Feature 4-9:<br/>Other features"]
    end

    subgraph "TREE ENSEMBLE"
        I1 --> T1["Tree 1"]
        I2 --> T1
        I3 --> T1
        I4 --> T1

        I1 --> T2["Tree 2"]
        I2 --> T2
        I3 --> T2
        I4 --> T2

        I1 --> T3["Tree 3"]
        I2 --> T3
        I3 --> T3
        I4 --> T3

        I1 --> TN["Tree N<br/>(100 trees)"]
        I2 --> TN
        I3 --> TN
        I4 --> TN
    end

    subgraph "AGGREGATION"
        T1 --> AGG["Weighted Sum"]
        T2 --> AGG
        T3 --> AGG
        TN --> AGG
    end

    subgraph "OUTPUT LAYER"
        AGG --> O1["Predicted Value"]
        AGG --> O2["Confidence Score"]
        AGG --> O3["Risk Score"]
    end

    subgraph "CALIBRATION"
        O1 --> CAL["Confidence<br/>Calibration"]
        O2 --> CAL
        O3 --> CAL
        CAL --> FINAL["Final Prediction"]
    end

    style T1 fill:#FFE66D,stroke:#333,color:#000
    style T2 fill:#FFE66D,stroke:#333,color:#000
    style T3 fill:#FFE66D,stroke:#333,color:#000
    style TN fill:#FFE66D,stroke:#333,color:#000
    style AGG fill:#4A90E2,stroke:#333,color:#fff
    style FINAL fill:#50C878,stroke:#333,color:#fff
```

## 8. Dispute Resolution Flow

```mermaid
sequenceDiagram
    participant User
    participant Appraisal as AICollateralAppraisal
    participant Oracle as ML Oracle
    participant Worker
    participant Admin

    User->>Appraisal: Request appraisal
    Appraisal->>Oracle: Create job
    Oracle->>Worker: Assign job
    Worker->>Oracle: Submit result (value=$1000)
    Oracle->>Appraisal: Prediction available

    Note over User: User believes value is wrong

    User->>Oracle: raiseDispute(jobId, "Value too low")
    Oracle->>Oracle: Set status = DISPUTED

    Admin->>Oracle: Review dispute
    Admin->>Admin: Compare with other oracles
    Admin->>Admin: Check worker history

    alt Worker at fault
        Admin->>Oracle: resolveDispute(jobId, true)
        Oracle->>Worker: Slash stake (10%)
        Oracle->>Worker: reputation -= 5
        Oracle->>User: Refund job reward
        Oracle->>Appraisal: Mark appraisal invalid
    else Worker not at fault
        Admin->>Oracle: resolveDispute(jobId, false)
        Oracle->>Oracle: Keep job as completed
        Oracle-->>User: Dispute rejected
    end
```

## 9. Auto-Reappraisal Trigger

```mermaid
graph TB
    subgraph "MONITORING"
        M1["Price Oracle Update"]
        M2["Volume Spike Detected"]
        M3["Liquidity Change"]
        M4["Time Elapsed (&gt;24h)"]
    end

    subgraph "TRIGGER CONDITIONS"
        M1 --> T1{"Price Δ &gt; 10%?"}
        M2 --> T2{"Volume Δ &gt; 50%?"}
        M3 --> T3{"Liquidity Δ &gt; 30%?"}
        M4 --> T4{"Appraisal Expired?"}
    end

    subgraph "REAPPRAISAL DECISION"
        T1 -->|YES| TRIGGER["Trigger Reappraisal"]
        T2 -->|YES| TRIGGER
        T3 -->|YES| TRIGGER
        T4 -->|YES| TRIGGER

        T1 -->|NO| WAIT["Continue Monitoring"]
        T2 -->|NO| WAIT
        T3 -->|NO| WAIT
        T4 -->|NO| WAIT
    end

    subgraph "EXECUTION"
        TRIGGER --> AUTO["Automatic Reappraisal"]
        AUTO --> COMPARE["Compare New vs Old"]
        COMPARE --> UPDATE["Update Stored Value"]
    end

    subgraph "RISK ADJUSTMENT"
        UPDATE --> CHECK{"Value Decreased?"}
        CHECK -->|YES| MARGIN["Margin Call Alert"]
        CHECK -->|NO| SAFE["Position Safe"]
    end

    style TRIGGER fill:#FFE66D,stroke:#333,color:#000
    style AUTO fill:#4A90E2,stroke:#333,color:#fff
    style MARGIN fill:#FF6B6B,stroke:#333,color:#fff
    style SAFE fill:#50C878,stroke:#333,color:#fff
```

## 10. Gas Optimization Strategy

```mermaid
graph LR
    subgraph "EXPENSIVE ON-CHAIN"
        E1["❌ Full ML Inference<br/>(~10M gas)"]
        E2["❌ Store All Features<br/>(~500K gas)"]
        E3["❌ Complex Math<br/>(~200K gas)"]
    end

    subgraph "OPTIMIZED HYBRID"
        O1["✓ Off-chain Inference<br/>(0 gas)"]
        O2["✓ Store Only Hash<br/>(~20K gas)"]
        O3["✓ Oracle Validates<br/>(~50K gas)"]
    end

    subgraph "TOTAL COST"
        E1 --> BEFORE["Before:<br/>~10.7M gas<br/>~$300 @ 50 gwei"]
        O1 --> AFTER["After:<br/>~70K gas<br/>~$2 @ 50 gwei"]
    end

    style E1 fill:#FF6B6B,stroke:#333,color:#fff
    style E2 fill:#FF6B6B,stroke:#333,color:#fff
    style E3 fill:#FF6B6B,stroke:#333,color:#fff
    style O1 fill:#50C878,stroke:#333,color:#fff
    style O2 fill:#50C878,stroke:#333,color:#fff
    style O3 fill:#50C878,stroke:#333,color:#fff
    style BEFORE fill:#FF6B6B,stroke:#333,color:#fff
    style AFTER fill:#50C878,stroke:#333,color:#fff
```

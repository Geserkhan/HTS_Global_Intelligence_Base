# GROUP 5: Self-Reinforcing Stablecoin (RLX) - Architecture Diagrams

## 1. Contribution Score & Dynamic Collateral System

```mermaid
graph TB
    subgraph "USER CONTRIBUTIONS"
        C1["Financial: $10,000"]
        C2["Staking: 180 days"]
        C3["Governance: 50 votes"]
    end

    subgraph "SCORE CALCULATION"
        S1["Contribution Score<br/>40% weight"]
        S2["Staking Score<br/>30% weight"]
        S3["Governance Score<br/>30% weight"]
        S4["Total Score: 75/100"]
    end

    subgraph "COLLATERAL RATIO"
        R1["Base Ratio: 150%"]
        R2["Discount: Score × 0.5%"]
        R3["User Ratio: 112.5%"]
    end

    subgraph "MINTING POWER"
        M1["Collateral: $1,000"]
        M2["Standard User: $666 RLX"]
        M3["High Score User: $888 RLX"]
        M4["+33% Minting Power!"]
    end

    C1 --> S1
    C2 --> S2
    C3 --> S3
    S1 & S2 & S3 --> S4
    S4 --> R2
    R1 & R2 --> R3
    R3 --> M3
    R1 --> M2
    M3 --> M4

    style S4 fill:#FFE66D,stroke:#333,color:#000
    style R3 fill:#4A90E2,stroke:#333,color:#fff
    style M4 fill:#50C878,stroke:#333,color:#fff
```

## 2. Dynamic Collateral Adjustment

```mermaid
graph LR
    subgraph "CONTRIBUTION LEVELS"
        L1["Beginner<br/>Score: 0-25<br/>Ratio: 150%"]
        L2["Active<br/>Score: 26-50<br/>Ratio: 137.5%"]
        L3["Advanced<br/>Score: 51-75<br/>Ratio: 125%"]
        L4["Expert<br/>Score: 76-100<br/>Ratio: 100-112.5%"]
    end

    subgraph "BENEFITS"
        B1["Standard Minting"]
        B2["+8.3% Efficiency"]
        B3["+16.7% Efficiency"]
        B4["+33% Efficiency"]
    end

    L1 --> B1
    L2 --> B2
    L3 --> B3
    L4 --> B4

    style L1 fill:#FF6B6B,stroke:#333,color:#fff
    style L2 fill:#FFE66D,stroke:#333,color:#000
    style L3 fill:#95E1D3,stroke:#333,color:#000
    style L4 fill:#50C878,stroke:#333,color:#fff
```

## 3. Minting & Liquidation Flow

```mermaid
sequenceDiagram
    participant User
    participant RLX
    participant Oracle
    participant Liquidator

    Note over User,Liquidator: Phase 1: Contribution Building

    User->>RLX: Contribute to ecosystem
    User->>RLX: Stake tokens (180 days)
    User->>RLX: Participate in governance

    Oracle->>RLX: updateContributionScore(user, $10k, 180 days, 50 votes)
    RLX->>RLX: Calculate score: 75/100
    RLX->>RLX: Set ratio: 112.5%

    Note over User,Liquidator: Phase 2: Minting RLX

    User->>RLX: Deposit $1,000 collateral
    RLX->>RLX: Check ratio: $1,000 / 112.5% = $888
    RLX->>User: Mint 888 RLX

    Note over User,Liquidator: Phase 3: Price Drop

    Oracle->>RLX: Update collateral price: -20%
    RLX->>RLX: New value: $800
    RLX->>RLX: Ratio: 90% (< 120% threshold)

    Liquidator->>RLX: liquidatePosition(user, positionId)
    RLX->>RLX: Burn 888 RLX
    RLX->>Liquidator: Transfer $800 collateral
```

## 4. Self-Reinforcing Mechanism

```mermaid
graph TB
    START["User Joins"] --> CONTRIB["Contribute to Ecosystem"]
    CONTRIB --> SCORE["Earn Contribution Score"]
    SCORE --> DISCOUNT["Get Collateral Discount"]
    DISCOUNT --> MINT["Mint More RLX"]
    MINT --> VALUE["Hold RLX Tokens"]
    VALUE --> INCENTIVE["Incentivized to Contribute More"]
    INCENTIVE --> CONTRIB

    style CONTRIB fill:#4ECDC4,stroke:#333,color:#fff
    style SCORE fill:#FFE66D,stroke:#333,color:#000
    style DISCOUNT fill:#4A90E2,stroke:#333,color:#fff
    style INCENTIVE fill:#50C878,stroke:#333,color:#fff
```

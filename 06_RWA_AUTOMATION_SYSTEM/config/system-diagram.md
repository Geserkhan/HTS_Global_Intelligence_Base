# RWA Automation System - Visual Architecture

## System Flow Diagram

```mermaid
graph TB
    subgraph "LAYER 1: BLX Multi-RWA Feed"
        A1["Bloomberg Data<br/>US Treasuries 30%"]
        A2["Asset Manager<br/>Private Credit 20%"]
        A3["LBMA<br/>Gold 50%"]
        A1 --> BLX["BLX Contract<br/>Multi-RWA Basket"]
        A2 --> BLX
        A3 --> BLX
    end

    subgraph "LAYER 2: TLX Trigger"
        BLX --> CALC["LTV Calculator<br/>Target: 120%"]
        CALC --> TRIGGER["Trigger Logic<br/>If LTV > 125%"]
        TRIGGER --> HTLX["HTLX Contract<br/>60-day Timelock"]
    end

    subgraph "LAYER 3: Automation & Cross-chain"
        HTLX --> GELATO["Gelato Keeper<br/>Condition Monitor"]
        GELATO --> AXELAR["Axelar Bridge<br/>Multi-chain Sync"]
        AXELAR --> EXECUTION["Keeper Execution<br/>Sub-60s Settlement"]
    end

    subgraph "LAYER 4: Trust Automation"
        EXECUTION --> POT["Proof of Trust<br/>7-Oracle Consensus"]
        POT --> AUDIT["Audit Trail<br/>Immutable Log"]
        AUDIT --> RULE["Rule Engine<br/>Compliance Check"]
        RULE --> TRUST["Trust Score<br/>Output"]
        TRUST --> SETTLEMENT["Digital LC<br/>Settlement"]
    end

    style BLX fill:#4A90E2,stroke:#333,color:#fff
    style HTLX fill:#7B68EE,stroke:#333,color:#fff
    style EXECUTION fill:#50C878,stroke:#333,color:#fff
    style TRUST fill:#FF6B6B,stroke:#333,color:#fff
```

## Detailed Component Diagram

```mermaid
graph LR
    subgraph "Data Sources"
        BB[Bloomberg<br/>API]
        AM[Asset Manager<br/>API]
        LB[LBMA<br/>API]
    end

    subgraph "Smart Contracts"
        SC1[BLXMultiRWAFeed]
        SC2[HTLXTrigger]
        SC3[GelatoAutomation]
        SC4[AxelarBridge]
        SC5[ProofOfTrust]
        SC6[AuditTrail]
        SC7[RuleEngine]
        SC8[DigitalLC]
    end

    subgraph "External Services"
        GEL[Gelato<br/>Network]
        AXL[Axelar<br/>Network]
    end

    BB --> SC1
    AM --> SC1
    LB --> SC1
    SC1 --> SC2
    SC2 --> SC3
    SC3 --> GEL
    SC3 --> SC4
    SC4 --> AXL
    SC3 --> SC5
    SC5 --> SC6
    SC6 --> SC7
    SC7 --> SC8

    style SC1 fill:#4A90E2
    style SC2 fill:#7B68EE
    style SC3 fill:#50C878
    style SC8 fill:#FF6B6B
```

## Sequence Diagram - Complete Flow

```mermaid
sequenceDiagram
    participant Oracle
    participant BLX
    participant HTLX
    participant Gelato
    participant PoT
    participant Audit
    participant Rules
    participant LC

    Oracle->>BLX: Submit Price Data
    BLX->>BLX: Calculate Basket Value
    BLX->>HTLX: Update Collateral
    HTLX->>HTLX: Calculate LTV

    alt LTV > 125%
        HTLX->>HTLX: Activate Trigger
        HTLX->>HTLX: Queue Timelock (60 days)
        Gelato->>HTLX: Monitor Condition

        alt Timelock Expired
            Gelato->>HTLX: Execute Trigger
            HTLX->>PoT: Request Consensus

            loop 7 Oracles
                Oracle->>PoT: Submit Data
            end

            PoT->>PoT: Calculate Median
            PoT->>PoT: Update Trust Scores
            PoT->>Audit: Log Consensus
            Audit->>Rules: Evaluate Compliance
            Rules->>Rules: Check Score (>80%)

            alt Compliant
                Rules->>LC: Approve Settlement
                LC->>LC: Execute Settlement
                LC->>Audit: Log Settlement
            else Non-Compliant
                Rules->>Audit: Log Violation
            end
        end
    end
```

## State Transition Diagram - Digital LC

```mermaid
stateDiagram-v2
    [*] --> PENDING: Issue LC
    PENDING --> ISSUED: Approve
    ISSUED --> DOCUMENTS_SUBMITTED: Submit Docs
    DOCUMENTS_SUBMITTED --> VERIFIED: Verify All
    VERIFIED --> SETTLED: Execute Settlement
    SETTLED --> [*]

    PENDING --> CANCELLED: Cancel
    ISSUED --> CANCELLED: Cancel
    DOCUMENTS_SUBMITTED --> CANCELLED: Cancel
    ISSUED --> EXPIRED: Time Expired
    DOCUMENTS_SUBMITTED --> EXPIRED: Time Expired
    CANCELLED --> [*]
    EXPIRED --> [*]
```

## Trust Score Flow

```mermaid
flowchart TD
    START([Start]) --> SUBMIT[Oracle Submits Data]
    SUBMIT --> COLLECT[Collect 5+ Submissions]
    COLLECT --> MEDIAN[Calculate Median Value]
    MEDIAN --> COMPARE{Within 5%<br/>Deviation?}

    COMPARE -->|Yes| INCREASE[Trust Score +1%]
    COMPARE -->|No| DECREASE[Trust Score -2%]

    INCREASE --> UPDATE[Update Score]
    DECREASE --> UPDATE

    UPDATE --> CHECK{Score < 80%?}
    CHECK -->|Yes| ALERT[Compliance Alert]
    CHECK -->|No| CONTINUE[Continue]

    ALERT --> END([End])
    CONTINUE --> END
```

## Cross-Chain Synchronization

```mermaid
graph TB
    subgraph "Source Chain (Ethereum)"
        SC1[BLX Feed]
        SC2[HTLX Trigger]
        SC3[Axelar Gateway]
    end

    subgraph "Axelar Network"
        AX1[Validators]
        AX2[Relayers]
    end

    subgraph "Destination Chains"
        DC1[Polygon<br/>Gateway]
        DC2[Arbitrum<br/>Gateway]
        DC3[Optimism<br/>Gateway]
        DC4[Avalanche<br/>Gateway]
        DC5[BSC<br/>Gateway]
    end

    SC1 --> SC2
    SC2 --> SC3
    SC3 --> AX1
    AX1 --> AX2
    AX2 --> DC1
    AX2 --> DC2
    AX2 --> DC3
    AX2 --> DC4
    AX2 --> DC5

    style SC3 fill:#50C878
    style AX1 fill:#FFD700
    style AX2 fill:#FFD700
```

## LTV Monitoring Flow

```mermaid
flowchart LR
    START([Start]) --> FETCH[Fetch Basket Value]
    FETCH --> CALC[Calculate LTV]
    CALC --> CHECK{LTV Level?}

    CHECK -->|< 120%| SAFE[Safe - No Action]
    CHECK -->|120-125%| WARN[Warning Alert]
    CHECK -->|125-130%| PREP[Liquidation Prep]
    CHECK -->|> 130%| CRIT[Critical Alert]

    SAFE --> WAIT[Wait 5 min]
    WARN --> LOG1[Log Event]
    PREP --> TRIGGER[Activate Trigger]
    CRIT --> EMERGENCY[Emergency Action]

    LOG1 --> WAIT
    TRIGGER --> TIMELOCK[60-day Timelock]
    TIMELOCK --> WAIT
    EMERGENCY --> WAIT
    WAIT --> FETCH
```

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT APPLICATIONS                          │
│                    (Web Dashboard, Mobile App, API)                  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────┴──────────────────────────────────────┐
│                        LAYER 4: SETTLEMENT                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ Proof of     │  │  Audit       │  │  Rule        │  ┌─────────┐ │
│  │ Trust        ├──┤  Trail       ├──┤  Engine      ├──┤Digital  │ │
│  │ (7 Oracles)  │  │  (Immutable) │  │  (Rules)     │  │LC       │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └─────────┘ │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────┴──────────────────────────────────────┐
│                  LAYER 3: AUTOMATION & CROSS-CHAIN                   │
│  ┌──────────────────────────┐  ┌─────────────────────────────────┐ │
│  │ Gelato Automation        │  │ Axelar Bridge                   │ │
│  │ - Condition Monitor      │  │ - Multi-chain Sync              │ │
│  │ - Keeper Execution       │  │ - Message Verification          │ │
│  │ - <60s Settlement        │  │ - 6 Chains Supported            │ │
│  └──────────────────────────┘  └─────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────┴──────────────────────────────────────┐
│                     LAYER 2: TRIGGER LOGIC                           │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ HTLX Trigger System                                           │  │
│  │ - LTV Calculator (Target: 120%, Trigger: 125%)               │  │
│  │ - Timelock (60 days)                                         │  │
│  │ - Trigger Queue Management                                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────┴──────────────────────────────────────┐
│                   LAYER 1: DATA AGGREGATION                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                    │
│  │ Bloomberg  │  │   Asset    │  │   LBMA     │                    │
│  │ US Treas.  │  │  Manager   │  │   Gold     │                    │
│  │   (30%)    │  │ Priv. Cred.│  │   (50%)    │                    │
│  │            │  │   (20%)    │  │            │                    │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘                    │
│        └─────────────┬──┴──────────────┘                            │
│                      │                                               │
│         ┌────────────┴────────────┐                                 │
│         │  BLX Multi-RWA Basket   │                                 │
│         │  Weighted Valuation     │                                 │
│         └─────────────────────────┘                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

**Note**: This diagram shows the complete RWA Automation System architecture as originally requested. All components are interconnected to provide a seamless, automated, and trustless settlement system for real-world assets.

**Version**: 1.0.0
**Created**: 2025-11-18
**Maintainer**: HTS DAO Technical Team

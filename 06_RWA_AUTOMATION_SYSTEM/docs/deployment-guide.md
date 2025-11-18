# RWA Automation System - Deployment Guide

**Version**: 1.0.0
**Target Networks**: Polygon Mainnet, Arbitrum, Base (EVM-compatible chains)
**Last Updated**: 2025-11-18

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Smart Contract Deployment](#smart-contract-deployment)
4. [Gelato Network Setup](#gelato-network-setup)
5. [Oracle Configuration](#oracle-configuration)
6. [Monitoring & Alerting](#monitoring--alerting)
7. [Security Checklist](#security-checklist)
8. [Post-Deployment Verification](#post-deployment-verification)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| **Node.js** | 18+ | JavaScript runtime |
| **npm/yarn** | Latest | Package manager |
| **Hardhat** | 2.19+ | Smart contract framework |
| **Foundry** | Latest (optional) | Advanced contract testing |
| **Docker** | 20+ | Containerized services |
| **Git** | 2.30+ | Version control |

### Installation

```bash
# Install Node.js dependencies
npm install --save-dev hardhat @nomiclabs/hardhat-ethers ethers
npm install @openzeppelin/contracts
npm install @chainlink/contracts
npm install @gelatonetwork/ops-sdk

# Install Foundry (optional, for advanced testing)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Required Accounts & Keys

- [ ] **Deployer Wallet**: With sufficient native tokens for gas (0.5 ETH recommended)
- [ ] **Admin Multisig**: Gnosis Safe or similar (3/5 signature threshold)
- [ ] **Gelato API Key**: From https://app.gelato.network
- [ ] **Infura/Alchemy API Key**: For RPC access
- [ ] **Etherscan API Key**: For contract verification
- [ ] **TheGraph API Key**: For subgraph deployment

---

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/HTS-DAO/rwa-automation-system.git
cd rwa-automation-system
```

### 2. Configure Environment Variables

Create `.env` file in project root:

```bash
# Network Configuration
NETWORK=polygon
RPC_URL=https://polygon-mainnet.infura.io/v3/YOUR_INFURA_KEY
CHAIN_ID=137

# Wallet Configuration
DEPLOYER_PRIVATE_KEY=0x...
ADMIN_MULTISIG_ADDRESS=0x...

# API Keys
ETHERSCAN_API_KEY=your_etherscan_key
GELATO_API_KEY=your_gelato_key
THEGRAPH_API_KEY=your_thegraph_key

# Gelato Network Configuration
GELATO_RELAY_URL=https://relay.gelato.digital
GELATO_EXECUTOR_ADDRESS=0x... # Get from Gelato dashboard

# Oracle Addresses (Polygon Mainnet)
CHAINLINK_XAU_USD=0x0C466540B2ee1a31b441671eac0ca886e051E410
CHAINLINK_USDC_USD=0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7

# Contract Addresses (will be filled after deployment)
BLX_MULTI_RWA_FEED=
HTLX_TRIGGER=
GELATO_AUTOMATION=

# Monitoring
GRAFANA_API_KEY=your_grafana_key
PAGERDUTY_API_KEY=your_pagerduty_key
```

### 3. Hardhat Configuration

Edit `hardhat.config.js`:

```javascript
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("solidity-coverage");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    polygon: {
      url: process.env.RPC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      chainId: 137,
      gasPrice: 50000000000 // 50 gwei
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      chainId: 42161
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY
  }
};
```

---

## Smart Contract Deployment

### Deployment Order

Deploy contracts in this sequence to handle dependencies:

1. **Layer 1**: BLX Multi-RWA Feed (no dependencies)
2. **Layer 2**: HTLX Trigger (depends on Layer 1)
3. **Layer 3**: Gelato Automation (depends on Layer 1 & 2)

### 1. Deploy Layer1_BLXMultiRWAFeed.sol

```bash
# Compile contracts
npx hardhat compile

# Deploy Layer 1
npx hardhat run scripts/deploy-layer1.js --network polygon
```

**Deploy Script** (`scripts/deploy-layer1.js`):

```javascript
const hre = require("hardhat");

async function main() {
  console.log("Deploying Layer1_BLXMultiRWAFeed...");

  const BLXMultiRWAFeed = await hre.ethers.getContractFactory("Layer1_BLXMultiRWAFeed");

  const feed = await BLXMultiRWAFeed.deploy(
    process.env.CHAINLINK_XAU_USD,      // Gold price feed
    process.env.CHAINLINK_USDC_USD,     // USDC price feed
    process.env.ADMIN_MULTISIG_ADDRESS  // Admin address
  );

  await feed.deployed();
  console.log("Layer1_BLXMultiRWAFeed deployed to:", feed.address);

  // Verify on Etherscan
  console.log("Waiting for block confirmations...");
  await feed.deployTransaction.wait(5);

  await hre.run("verify:verify", {
    address: feed.address,
    constructorArguments: [
      process.env.CHAINLINK_XAU_USD,
      process.env.CHAINLINK_USDC_USD,
      process.env.ADMIN_MULTISIG_ADDRESS
    ]
  });

  console.log("✅ Layer1 deployed and verified!");
  console.log("📝 Update .env with: BLX_MULTI_RWA_FEED=" + feed.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

**Expected Output**:
```
Deploying Layer1_BLXMultiRWAFeed...
Layer1_BLXMultiRWAFeed deployed to: 0x1234...5678
Waiting for block confirmations...
✅ Layer1 deployed and verified!
📝 Update .env with: BLX_MULTI_RWA_FEED=0x1234...5678
```

### 2. Deploy Layer2_HTLXTrigger.sol

```bash
npx hardhat run scripts/deploy-layer2.js --network polygon
```

**Deploy Script** (`scripts/deploy-layer2.js`):

```javascript
const hre = require("hardhat");

async function main() {
  console.log("Deploying Layer2_HTLXTrigger...");

  const HTLXTrigger = await hre.ethers.getContractFactory("Layer2_HTLXTrigger");

  const htlx = await HTLXTrigger.deploy(
    process.env.BLX_MULTI_RWA_FEED,     // Layer1 address
    process.env.ADMIN_MULTISIG_ADDRESS  // Admin address
  );

  await htlx.deployed();
  console.log("Layer2_HTLXTrigger deployed to:", htlx.address);

  // Verify on Etherscan
  await htlx.deployTransaction.wait(5);
  await hre.run("verify:verify", {
    address: htlx.address,
    constructorArguments: [
      process.env.BLX_MULTI_RWA_FEED,
      process.env.ADMIN_MULTISIG_ADDRESS
    ]
  });

  console.log("✅ Layer2 deployed and verified!");
  console.log("📝 Update .env with: HTLX_TRIGGER=" + htlx.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

### 3. Deploy Layer3_GelatoAutomation.sol

```bash
npx hardhat run scripts/deploy-layer3.js --network polygon
```

**Deploy Script** (`scripts/deploy-layer3.js`):

```javascript
const hre = require("hardhat");

async function main() {
  console.log("Deploying Layer3_GelatoAutomation...");

  const GelatoAutomation = await hre.ethers.getContractFactory("Layer3_GelatoAutomation");

  const gelato = await GelatoAutomation.deploy(
    process.env.BLX_MULTI_RWA_FEED,     // Layer1 address
    process.env.HTLX_TRIGGER,           // Layer2 address
    process.env.GELATO_EXECUTOR_ADDRESS, // Gelato executor
    process.env.ADMIN_MULTISIG_ADDRESS  // Admin address
  );

  await gelato.deployed();
  console.log("Layer3_GelatoAutomation deployed to:", gelato.address);

  // Verify on Etherscan
  await gelato.deployTransaction.wait(5);
  await hre.run("verify:verify", {
    address: gelato.address,
    constructorArguments: [
      process.env.BLX_MULTI_RWA_FEED,
      process.env.HTLX_TRIGGER,
      process.env.GELATO_EXECUTOR_ADDRESS,
      process.env.ADMIN_MULTISIG_ADDRESS
    ]
  });

  console.log("✅ Layer3 deployed and verified!");
  console.log("📝 Update .env with: GELATO_AUTOMATION=" + gelato.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

---

## Gelato Network Setup

### Overview

Gelato Network provides decentralized keeper infrastructure for automated monitoring and execution.

**Reference**: See detailed guide at `gelato-integration.md`

### 1. Create Gelato Account

1. Visit https://app.gelato.network
2. Connect wallet (use deployer wallet)
3. Deposit GELATO tokens for task payments

```bash
# Minimum recommended deposit: 100 GELATO
# Calculate: (tasks_per_day × gas_cost × 30_days × safety_margin)
```

### 2. Create Automation Task

Using Gelato SDK:

```javascript
const { GelatoOpsSDK } = require("@gelatonetwork/ops-sdk");

async function createGelatoTask() {
  const gelatoOps = new GelatoOpsSDK({
    network: "polygon",
    apiKey: process.env.GELATO_API_KEY
  });

  const taskId = await gelatoOps.createTask({
    name: "RWA Liquidation Monitor",
    execAddress: process.env.GELATO_AUTOMATION,
    execSelector: "executeLiquidation(address,bytes)",
    resolverAddress: process.env.GELATO_AUTOMATION,
    resolverData: "checker()",
    interval: 12, // seconds
    maxGasPrice: 200, // gwei
    retries: 3
  });

  console.log("Gelato Task Created:", taskId);
  return taskId;
}

createGelatoTask();
```

### 3. Configure Keeper Nodes

Deploy at least **3 redundant keeper nodes** for high availability:

**Node 1**: Primary (us-east-1)
**Node 2**: Secondary (eu-west-1)
**Node 3**: Tertiary (ap-southeast-1)

Each node configuration:

```yaml
# gelato-node-config.yml
network: polygon
chain_id: 137
rpc_url: ${RPC_URL}
contracts:
  - address: ${GELATO_AUTOMATION}
    abi_path: ./abis/Layer3_GelatoAutomation.json
    functions:
      - checker
      - executeLiquidation
monitoring:
  interval: 12 # seconds
  max_gas_price: 200 # gwei
  retry_attempts: 3
  retry_delay: 5 # seconds
security:
  key_rotation_days: 30
  rate_limit_per_minute: 100
alerting:
  pagerduty_key: ${PAGERDUTY_API_KEY}
  slack_webhook: ${SLACK_WEBHOOK_URL}
```

**Deploy Keeper Node (Docker)**:

```bash
docker run -d \
  --name gelato-keeper-1 \
  -e NETWORK=polygon \
  -e RPC_URL=${RPC_URL} \
  -e PRIVATE_KEY=${KEEPER_PRIVATE_KEY_1} \
  -e GELATO_API_KEY=${GELATO_API_KEY} \
  -v $(pwd)/gelato-node-config.yml:/config.yml \
  gelatonetwork/keeper:latest \
  --config /config.yml
```

### 4. Off-Chain Monitoring Infrastructure

Deploy monitoring stack for keeper health:

```bash
# Deploy Prometheus + Grafana
docker-compose up -d

# File: docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
    volumes:
      - ./grafana-dashboards:/etc/grafana/provisioning/dashboards
```

**Prometheus Configuration** (`prometheus.yml`):

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'gelato-keepers'
    static_configs:
      - targets:
          - 'keeper-1:9090'
          - 'keeper-2:9090'
          - 'keeper-3:9090'

  - job_name: 'smart-contracts'
    metrics_path: '/metrics'
    static_configs:
      - targets:
          - 'polygon-node:8545'
```

---

## Oracle Configuration

### Chainlink Price Feeds

Configure Chainlink oracles for RWA price data:

**Polygon Mainnet Addresses**:

| Asset | Feed Address | Update Frequency |
|-------|--------------|------------------|
| XAU/USD (Gold) | `0x0C466540B2ee1a31b441671eac0ca886e051E410` | 1 hour / 0.5% deviation |
| USDC/USD | `0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7` | 24 hours / 0.5% deviation |

### Custom Oracle Setup (for Real Estate & Trade Finance)

Deploy custom oracle for non-standard RWAs:

```javascript
// Deploy custom oracle
const CustomOracle = await hre.ethers.getContractFactory("CustomRWAOracle");
const oracle = await CustomOracle.deploy(
  process.env.ORACLE_OPERATOR_ADDRESS,
  process.env.ADMIN_MULTISIG_ADDRESS
);

// Register oracle with Layer1
const layer1 = await hre.ethers.getContractAt(
  "Layer1_BLXMultiRWAFeed",
  process.env.BLX_MULTI_RWA_FEED
);

await layer1.addCustomOracle(
  "PROPERTY", // Asset type
  oracle.address
);
```

---

## Monitoring & Alerting

### Key Metrics to Monitor

| Metric | Alert Threshold | Action |
|--------|-----------------|--------|
| Keeper uptime | < 99% | Page on-call engineer |
| Liquidation latency | > 60 seconds | Investigate keeper performance |
| Oracle staleness | > 1 hour | Check Chainlink node status |
| Gas price spike | > 500 gwei | Pause non-critical operations |
| Contract balance | < 10 MATIC | Top up keeper wallets |

### Grafana Dashboard

Import dashboard template from `monitoring/grafana-dashboard.json`:

**Key Panels**:
1. Keeper node health (uptime, latency)
2. Liquidation count (24h rolling)
3. Gas consumption (per operation)
4. Oracle price updates (freshness)
5. HTLX settlement times

### PagerDuty Integration

```bash
# Configure PagerDuty alerts
curl -X POST https://api.pagerduty.com/incidents \
  -H "Authorization: Token token=${PAGERDUTY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "incident": {
      "type": "incident",
      "title": "Keeper Node 1 Down",
      "service": {
        "id": "PXX1234",
        "type": "service_reference"
      },
      "urgency": "high"
    }
  }'
```

---

## Security Checklist

### Pre-Deployment

- [ ] Smart contracts audited by external firm
- [ ] Test coverage > 95%
- [ ] Fuzz testing completed (Foundry invariant tests)
- [ ] Admin keys stored in hardware wallets (Ledger/Trezor)
- [ ] Multisig threshold verified (3/5 minimum)
- [ ] Emergency pause mechanism tested
- [ ] Rate limiting configured (prevent spam attacks)
- [ ] Reentrancy guards enabled (OpenZeppelin)

### Post-Deployment

- [ ] Contract ownership transferred to multisig
- [ ] Deployer wallet private keys rotated
- [ ] Keeper wallet private keys secured (HSM recommended)
- [ ] Oracle addresses verified (not malicious)
- [ ] Gelato task configuration reviewed
- [ ] Monitoring alerts tested (trigger false alarm)
- [ ] Incident response playbook documented
- [ ] Bug bounty program launched (Immunefi recommended)

### Continuous Security

- [ ] Keeper key rotation (every 30 days)
- [ ] Oracle price feed monitoring (staleness checks)
- [ ] Contract upgrade simulation (testnet first)
- [ ] Security incident drills (quarterly)
- [ ] Access control audit (monthly)

---

## Post-Deployment Verification

### 1. Contract Verification

```bash
# Verify all contracts on Etherscan
npx hardhat verify --network polygon ${BLX_MULTI_RWA_FEED}
npx hardhat verify --network polygon ${HTLX_TRIGGER}
npx hardhat verify --network polygon ${GELATO_AUTOMATION}
```

### 2. Integration Tests

```bash
# Run end-to-end tests on mainnet fork
npx hardhat test --network hardhat

# Test scenarios:
# - Create position with RWA collateral
# - Simulate price drop (trigger liquidation)
# - Verify Gelato executes liquidation
# - Check TLX token minting
# - Test recovery flow
```

### 3. Keeper Health Check

```bash
# Check Gelato task status
curl -X GET https://api.gelato.network/tasks/${TASK_ID} \
  -H "Authorization: Bearer ${GELATO_API_KEY}"

# Expected response:
{
  "taskId": "0x...",
  "status": "active",
  "executions": 120,
  "lastExecution": "2025-11-18T12:00:00Z",
  "nextExecution": "2025-11-18T12:00:12Z"
}
```

### 4. Oracle Price Check

```javascript
const layer1 = await hre.ethers.getContractAt(
  "Layer1_BLXMultiRWAFeed",
  process.env.BLX_MULTI_RWA_FEED
);

const goldPrice = await layer1.getGoldPrice();
console.log("Gold Price (XAU/USD):", ethers.utils.formatUnits(goldPrice, 8));

// Expected: Current gold spot price (e.g., 2050.50 USD/oz)
```

---

## Troubleshooting

### Common Issues

#### Issue: Gelato task not executing

**Symptoms**: `checker()` returns `true` but liquidation not executed

**Diagnosis**:
```bash
# Check Gelato task status
curl https://api.gelato.network/tasks/${TASK_ID}

# Check keeper wallet balance
cast balance ${KEEPER_WALLET_ADDRESS} --rpc-url ${RPC_URL}
```

**Solutions**:
1. Top up keeper wallet (minimum 10 MATIC)
2. Check Gelato GELATO token balance
3. Verify gas price not exceeding `maxGasPrice`
4. Check contract not paused

---

#### Issue: Oracle price stale

**Symptoms**: Liquidations not triggering despite price changes

**Diagnosis**:
```javascript
const priceData = await layer1.getLatestPriceData();
const staleness = Date.now() / 1000 - priceData.timestamp;
console.log("Price staleness:", staleness, "seconds");
```

**Solutions**:
1. Verify Chainlink node operational (https://data.chain.link)
2. Check oracle contract not paused
3. Manually trigger price update (admin function)
4. Switch to backup oracle if available

---

#### Issue: High gas costs

**Symptoms**: Liquidations costing > 200k gas

**Diagnosis**:
```bash
# Profile gas usage
npx hardhat test --gas-reporter
```

**Solutions**:
1. Enable batched liquidations (multiple positions in one tx)
2. Optimize storage reads (use cached values)
3. Increase monitoring interval (12s → 30s) during high gas
4. Implement EIP-1559 dynamic gas pricing

---

## Rollback Procedure

If critical issues arise post-deployment:

### Emergency Pause

```javascript
// Pause all operations (admin only)
const layer3 = await hre.ethers.getContractAt(
  "Layer3_GelatoAutomation",
  process.env.GELATO_AUTOMATION
);

await layer3.pause(); // Requires multisig approval
```

### Contract Upgrade

```bash
# Deploy new implementation (if using proxy pattern)
npx hardhat run scripts/upgrade-contracts.js --network polygon

# Transfer ownership back to multisig
npx hardhat run scripts/transfer-ownership.js --network polygon
```

---

## Next Steps

After successful deployment:

1. **Gradual Rollout**: Start with 10% of TVL → 50% → 100%
2. **Monitor Closely**: 24/7 monitoring for first 7 days
3. **User Onboarding**: Provide documentation and support
4. **Iterate**: Collect feedback and optimize based on real usage

---

## Support Contacts

- **Technical Issues**: DevOps team (Slack: #rwa-automation-ops)
- **Security Incidents**: security@htsdao.org (PGP key available)
- **Gelato Support**: https://discord.gg/gelato
- **Chainlink Support**: https://discord.gg/chainlink

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-18
**Maintained By**: HTS DAO DevOps Team

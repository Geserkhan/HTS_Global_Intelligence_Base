# RWA Automation System - Deployment Guide

## Prerequisites

### Software Requirements
- Node.js >= 18.0.0
- npm >= 9.0.0
- Hardhat >= 2.19.0 or Foundry
- Git

### Network Requirements
- RPC endpoints for target networks
- Sufficient ETH/tokens for gas fees
- API keys for block explorers

### Accounts Required
- Deployer account (with sufficient funds)
- Admin account
- Oracle accounts (minimum 7)
- Keeper accounts
- Relayer accounts

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/your-org/HTS_Global_Intelligence_Base.git
cd HTS_Global_Intelligence_Base/06_RWA_AUTOMATION_SYSTEM
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Configure Environment
Create `.env` file:
```env
# Network RPC URLs
ETHEREUM_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY

# Private Keys (NEVER commit these)
DEPLOYER_PRIVATE_KEY=0x...
ADMIN_PRIVATE_KEY=0x...

# Oracle Addresses
ORACLE_1=0x...
ORACLE_2=0x...
ORACLE_3=0x...
ORACLE_4=0x...
ORACLE_5=0x...
ORACLE_6=0x...
ORACLE_7=0x...

# Gelato
GELATO_ADDRESS=0x...

# Axelar
AXELAR_GATEWAY_ETHEREUM=0x...
AXELAR_GATEWAY_POLYGON=0x...

# Etherscan API Keys
ETHERSCAN_API_KEY=...
POLYGONSCAN_API_KEY=...
```

## Deployment Steps

### Phase 1: Deploy Layer 1 (BLX Multi-RWA Feed)

```bash
npx hardhat run scripts/deploy-layer1.js --network mainnet
```

**Script**: `scripts/deploy-layer1.js`
```javascript
async function main() {
  const BLXMultiRWAFeed = await ethers.getContractFactory("BLXMultiRWAFeed");
  const blxFeed = await BLXMultiRWAFeed.deploy();
  await blxFeed.deployed();

  console.log("BLXMultiRWAFeed deployed to:", blxFeed.address);

  // Register oracles
  for (let i = 1; i <= 7; i++) {
    const oracle = process.env[`ORACLE_${i}`];
    await blxFeed.addOracle(oracle);
    console.log(`Oracle ${i} registered:`, oracle);
  }

  return blxFeed.address;
}
```

**Verification**:
```bash
npx hardhat verify --network mainnet DEPLOYED_ADDRESS
```

### Phase 2: Deploy Layer 2 (HTLX Trigger)

```bash
npx hardhat run scripts/deploy-layer2.js --network mainnet
```

**Script**: `scripts/deploy-layer2.js`
```javascript
async function main() {
  const blxFeedAddress = "0x..."; // From Phase 1

  const HTLXTrigger = await ethers.getContractFactory("HTLXTrigger");
  const htlxTrigger = await HTLXTrigger.deploy(blxFeedAddress);
  await htlxTrigger.deployed();

  console.log("HTLXTrigger deployed to:", htlxTrigger.address);

  return htlxTrigger.address;
}
```

### Phase 3: Deploy Layer 3 (Automation & Bridge)

#### 3.1: Deploy Gelato Automation
```bash
npx hardhat run scripts/deploy-gelato.js --network mainnet
```

```javascript
async function main() {
  const htlxTriggerAddress = "0x..."; // From Phase 2

  const GelatoAutomation = await ethers.getContractFactory("GelatoAutomation");
  const gelatoAutomation = await GelatoAutomation.deploy(htlxTriggerAddress);
  await gelatoAutomation.deployed();

  console.log("GelatoAutomation deployed to:", gelatoAutomation.address);

  // Add Gelato executor
  const gelatoAddress = process.env.GELATO_ADDRESS;
  await gelatoAutomation.addGelatoExecutor(gelatoAddress);

  return gelatoAutomation.address;
}
```

#### 3.2: Deploy Axelar Bridge
```bash
npx hardhat run scripts/deploy-axelar.js --network mainnet
```

```javascript
async function main() {
  const AxelarBridge = await ethers.getContractFactory("AxelarBridge");
  const axelarBridge = await AxelarBridge.deploy();
  await axelarBridge.deployed();

  console.log("AxelarBridge deployed to:", axelarBridge.address);

  // Configure chains
  const chains = [
    { id: 0, gateway: process.env.AXELAR_GATEWAY_ETHEREUM },
    { id: 1, gateway: process.env.AXELAR_GATEWAY_POLYGON },
    // ... more chains
  ];

  for (const chain of chains) {
    await axelarBridge.updateChainConfig(chain.id, chain.gateway, true);
  }

  return axelarBridge.address;
}
```

### Phase 4: Deploy Layer 4 (Trust & Settlement)

#### 4.1: Deploy Proof of Trust
```bash
npx hardhat run scripts/deploy-pot.js --network mainnet
```

```javascript
async function main() {
  const ProofOfTrust = await ethers.getContractFactory("ProofOfTrust");
  const proofOfTrust = await ProofOfTrust.deploy();
  await proofOfTrust.deployed();

  console.log("ProofOfTrust deployed to:", proofOfTrust.address);

  // Register 7 oracles
  for (let i = 1; i <= 7; i++) {
    const oracle = process.env[`ORACLE_${i}`];
    await proofOfTrust.registerOracle(oracle);
  }

  return proofOfTrust.address;
}
```

#### 4.2: Deploy Audit Trail
```bash
npx hardhat run scripts/deploy-audit.js --network mainnet
```

```javascript
async function main() {
  const AuditTrail = await ethers.getContractFactory("AuditTrail");
  const auditTrail = await AuditTrail.deploy();
  await auditTrail.deployed();

  console.log("AuditTrail deployed to:", auditTrail.address);

  return auditTrail.address;
}
```

#### 4.3: Deploy Rule Engine
```bash
npx hardhat run scripts/deploy-rules.js --network mainnet
```

```javascript
async function main() {
  const RuleEngine = await ethers.getContractFactory("RuleEngine");
  const ruleEngine = await RuleEngine.deploy();
  await ruleEngine.deployed();

  console.log("RuleEngine deployed to:", ruleEngine.address);

  return ruleEngine.address;
}
```

#### 4.4: Deploy Digital LC
```bash
npx hardhat run scripts/deploy-lc.js --network mainnet
```

```javascript
async function main() {
  const ruleEngineAddress = "0x..."; // From 4.3
  const auditTrailAddress = "0x..."; // From 4.2

  const DigitalLC = await ethers.getContractFactory("DigitalLC");
  const digitalLC = await DigitalLC.deploy(ruleEngineAddress, auditTrailAddress);
  await digitalLC.deployed();

  console.log("DigitalLC deployed to:", digitalLC.address);

  return digitalLC.address;
}
```

### Phase 5: System Integration

```bash
npx hardhat run scripts/integrate-system.js --network mainnet
```

```javascript
async function main() {
  // Grant roles across contracts

  // BLX Feed → HTLX Trigger
  await htlxTrigger.grantRole(KEEPER_ROLE, gelatoAutomation.address);

  // Gelato → Proof of Trust
  await proofOfTrust.grantRole(VALIDATOR_ROLE, gelatoAutomation.address);

  // Audit Trail → All contracts
  await auditTrail.addSystemRole(htlxTrigger.address);
  await auditTrail.addSystemRole(digitalLC.address);

  // Rule Engine → Digital LC
  await digitalLC.grantRole(COMPLIANCE_ROLE, ruleEngine.address);

  console.log("System integration completed");
}
```

## Post-Deployment Configuration

### 1. Verify All Contracts
```bash
npx hardhat verify --network mainnet ADDRESS CONSTRUCTOR_ARGS
```

### 2. Test Integration
```bash
npm run test:integration
```

### 3. Set Up Monitoring
- Configure Gelato tasks
- Set up alerting (PagerDuty, Slack)
- Deploy monitoring dashboard

### 4. Initialize Data
```bash
npx hardhat run scripts/initialize-data.js --network mainnet
```

## Multi-Chain Deployment

### Deploy to Polygon
```bash
npx hardhat run scripts/deploy-all.js --network polygon
```

### Deploy to Arbitrum
```bash
npx hardhat run scripts/deploy-all.js --network arbitrum
```

### Configure Cross-Chain Communication
```bash
npx hardhat run scripts/setup-crosschain.js
```

## Deployment Checklist

- [ ] All dependencies installed
- [ ] Environment variables configured
- [ ] Deployer account funded
- [ ] Oracle accounts prepared
- [ ] Layer 1 deployed and verified
- [ ] Layer 2 deployed and verified
- [ ] Layer 3 deployed and verified
- [ ] Layer 4 deployed and verified
- [ ] System integration completed
- [ ] Roles and permissions configured
- [ ] Initial data loaded
- [ ] Integration tests passed
- [ ] Monitoring configured
- [ ] Documentation updated
- [ ] Multi-chain deployment (if applicable)
- [ ] Security audit completed
- [ ] Emergency procedures documented

## Rollback Procedures

### Emergency Pause
```bash
npx hardhat run scripts/emergency-pause.js --network mainnet
```

### Rollback Deployment
```bash
npx hardhat run scripts/rollback.js --network mainnet --version previous
```

## Maintenance

### Upgrade Contracts (if using proxy pattern)
```bash
npx hardhat run scripts/upgrade.js --network mainnet
```

### Update Configuration
```bash
npx hardhat run scripts/update-config.js --network mainnet
```

## Troubleshooting

### Common Issues

**Issue**: Gas estimation failed
**Solution**: Increase gas limit manually

**Issue**: Oracle not submitting data
**Solution**: Check oracle permissions and RPC connection

**Issue**: Timelock too long
**Solution**: Use admin override (emergency only)

## Support

For deployment issues, contact:
- Technical Team: [email]
- Emergency Hotline: [phone]

---

**Version**: 1.0.0
**Last Updated**: 2025-11-18

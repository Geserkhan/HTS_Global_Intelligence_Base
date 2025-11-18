# RWA Automation System - Scripts

This directory contains deployment, management, and monitoring scripts for the RWA Automation System.

## Directory Structure

```
scripts/
├── deploy/              # Deployment scripts
├── setup/              # Configuration scripts
├── monitoring/         # Monitoring and alerting
└── utilities/          # Helper utilities
```

## Deployment Scripts

### Complete Deployment
```bash
npm run deploy:all --network mainnet
```

### Layer-by-Layer Deployment
```bash
npm run deploy:layer1 --network mainnet  # BLX Multi-RWA Feed
npm run deploy:layer2 --network mainnet  # HTLX Trigger
npm run deploy:layer3 --network mainnet  # Automation & Bridge
npm run deploy:layer4 --network mainnet  # Trust & Settlement
```

### Multi-Chain Deployment
```bash
npm run deploy:multichain
```

## Setup Scripts

### Initialize System
```bash
npm run setup:init
```

### Configure Roles
```bash
npm run setup:roles
```

### Register Oracles
```bash
npm run setup:oracles
```

## Monitoring Scripts

### Start Monitoring
```bash
npm run monitor:start
```

### Check System Health
```bash
npm run monitor:health
```

### View Metrics
```bash
npm run monitor:metrics
```

## Utility Scripts

### Verify Contracts
```bash
npm run verify:all
```

### Update Configuration
```bash
npm run config:update
```

### Emergency Pause
```bash
npm run emergency:pause
```

## Development

All scripts are written in JavaScript/TypeScript and use Hardhat or Foundry.

See [Deployment Guide](../docs/deployment-guide.md) for detailed instructions.

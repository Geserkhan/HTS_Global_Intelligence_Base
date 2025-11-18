# GROUP 5: Self-Reinforcing Stablecoin (RLX)
## Technical Specification

### Overview
Contribution-based stablecoin with dynamic collateral requirements that reward ecosystem participation.

### Key Innovation
Users who contribute more to the ecosystem (financially, through staking, or governance) receive lower collateral requirements, creating a self-reinforcing positive feedback loop.

### Contribution Score Formula
```
Score = (40% × Financial Contributions) +
        (30% × Staking Duration) +
        (30% × Governance Participation)
```

### Collateral Ratio Calculation
```
User Ratio = Base Ratio (150%) - (Score × 0.5%)

Examples:
- Score 0:   150% ratio
- Score 50:  125% ratio
- Score 100: 100% ratio (50% discount)
```

### Patent Claims
1. **Dynamic collateral system** based on ecosystem contribution metrics
2. **Self-reinforcing incentive mechanism** that rewards long-term participation
3. **Multi-dimensional scoring algorithm** for collateral requirement calculation

**Patent Status**: Pending

# MiniTreasure (MT)

<img width="1536" height="1024" alt="MiniTreasure Tokenomics Blueprint" src="https://github.com/user-attachments/assets/b460e8ae-d43b-4a11-b126-105a3f2bd442" />


> An ERC-20 token with built-in **vesting schedules** and **tiered staking rewards**, built with [Foundry](https://book.getfoundry.sh/) and [OpenZeppelin](https://www.openzeppelin.com/contracts).

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?logo=foundry&logoColor=black)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/tests-14%20passing-brightgreen)]()
[![Coverage](https://img.shields.io/badge/coverage-95%25-brightgreen)]()

---

##  Overview

**MiniTreasure (MT)** is a complete tokenomics toolkit consisting of three contracts:

| Contract | Purpose |
|----------|---------|
| [`MiniTreasure.sol`](src/MiniTreasure.sol) | The ERC-20 token — capped supply, burnable, mintable by owner |
| [`TokenVesting.sol`](src/TokenVesting.sol) | Multi-schedule vesting with cliffs, linear release, and revocation |
| [`MiniTreasureStaking.sol`](src/MiniTreasureStaking.sol) | Tiered staking with lock periods, APY rewards, and emergency exit |

Designed for teams launching a token with:
- **Team / investor allocations** that unlock over time (vesting)
- **Holder incentives** that reward long-term commitment (staking)
- **Fixed-supply economics** with controlled emission (mint cap)

---

##  Features

###  MiniTreasure Token (MT)
- **ERC-20 compliant** — standard transfers, approvals, allowances
- **Capped supply** — hard cap of 1,000,000,000 MT
- **Burnable** — any holder can burn their tokens
- **Owner-mintable** — mint new tokens up to the cap (only by owner)

###  Token Vesting
- **Multiple independent schedules** — one per beneficiary
- **Configurable cliff** — no tokens unlock before the cliff date
- **Linear release** — smooth vesting over the duration
- **Optional revocation** — owner can revoke unvested tokens (for team offboarding)
- **Beneficiary or owner** can trigger release
- **Vested tokens remain claimable** after revocation

###  MiniTreasure Staking
- **Three lock tiers** with escalating APY:

  | Lock Period | APY (Basis Points) | Effective APY |
  |-------------|--------------------|---------------|
  | 30 days     | 500                | 5%            |
  | 90 days     | 1,200              | 12%           |
  | 180 days    | 2,500              | 25%           |

- **Multiple concurrent stakes** per user (each tracked separately)
- **Rewards accrue linearly** by second, capped at lock end
- **Emergency unstake** — exit early with 50% penalty
- **Owner-funded reward pool** — rewards paid from a pre-funded reserve

---

##  Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       MiniTreasure (MT)                     │
│  • ERC20 + ERC20Burnable + Ownable                          │
│  • MAX_SUPPLY = 1,000,000,000 MT                            │
└───────────────┬─────────────────────────┬───────────────────┘
                │                         │
                │ transferred to          │ transferred to
                ▼                         ▼
┌───────────────────────────┐   ┌───────────────────────────┐
│      TokenVesting         │   │   MiniTreasureStaking     │
│  • Per-beneficiary        │   │  • Tiered locks           │
│  • Cliff + linear release │   │  • Linear rewards         │
│  • Optional revocation    │   │  • Emergency exit         │
└───────────────────────────┘   └───────────────────────────┘
```

**Trust model:** The deployer (owner) is trusted to:
- Mint up to the cap
- Create vesting schedules
- Revoke revocable schedules
- Fund the staking reward pool

Everything else is permissionless — anyone can stake, claim, or release their own vested tokens.

---

##  Quickstart

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed (`forge --version` should work)
- Git

### Installation

```bash
git clone <your-repo-url> minitreasure
cd minitreasure
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

Verify `remappings.txt` contains:
```
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

Run with verbosity for detailed traces:

```bash
forge test -vvv
```

Run a specific test:

```bash
forge test --match-test test_Stake -vvv
```

### Coverage

```bash
forge coverage --report summary
```

---

##  Usage

### Deploy locally (Anvil)

In one terminal:

```bash
anvil
```

In another:

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80  # Anvil's default key #0

forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

The script will:
1. Deploy `MiniTreasure` with 100M initial supply
2. Deploy `TokenVesting`
3. Deploy `MiniTreasureStaking`
4. Create a sample vesting schedule (10M tokens, 30-day cliff, 1-year linear)
5. Fund the staking reward pool (5M tokens)

### Deploy to a testnet (e.g. Base Sepolia)

```bash
export PRIVATE_KEY=<your-private-key>
export RPC_URL=https://sepolia.base.org
export ETHERSCAN_API_KEY=<your-basescan-key>

forge script script/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Interact with a deployed contract

```bash
# Check your MT balance
cast call <TOKEN_ADDRESS> "balanceOf(address)" <YOUR_ADDRESS> --rpc-url $RPC_URL

# Approve staking contract
cast send <TOKEN_ADDRESS> "approve(address,uint256)" <STAKING_ADDRESS> 1000000000000000000000 \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Stake 1000 MT for 90 days
cast send <STAKING_ADDRESS> "stake(uint256,uint256)" 1000000000000000000000 7776000 \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Check pending rewards
cast call <STAKING_ADDRESS> "pendingReward(address,uint256)" <YOUR_ADDRESS> 0 --rpc-url $RPC_URL
```

---

##  Testing

The test suite covers all three contracts with **14 tests** across functional, boundary, and revert paths.

```
Ran 4 tests for test/MiniTreasure.t.sol:MiniTreasureTest
[PASS] test_Burn()
[PASS] test_InitialSupply()
[PASS] test_Mint()
[PASS] test_MintExceedsMaxSupply()

Ran 5 tests for test/TokenVesting.t.sol:TokenVestingTest
[PASS] test_Cliff()
[PASS] test_CreateSchedule()
[PASS] test_LinearVesting()
[PASS] test_Release()
[PASS] test_Revoke()

Ran 5 tests for test/MiniTreasureStaking.t.sol:MiniTreasureStakingTest
[PASS] test_EmergencyUnstake()
[PASS] test_PendingReward()
[PASS] test_RevertUnstakeBeforeLock()
[PASS] test_Stake()
[PASS] test_UnstakeAfterLock()
```

### Coverage summary

| File | % Lines | % Statements | % Branches | % Funcs |
|------|---------|--------------|------------|---------|
| `src/MiniTreasure.sol` | 100% | 100% | 100% | 100% |
| `src/MiniTreasureStaking.sol` | 100% | 100% | ~89% | 100% |
| `src/TokenVesting.sol` | 100% | 100% | ~95% | 100% |

---

##  Project Structure

```
minitreasure/
├── foundry.toml                # Foundry configuration
├── remappings.txt              # Import remappings (OpenZeppelin)
├── README.md                   # This file
├── src/
│   ├── MiniTreasure.sol        # ERC-20 token
│   ├── TokenVesting.sol        # Vesting schedules
│   └── MiniTreasureStaking.sol # Tiered staking
├── test/
│   ├── MiniTreasure.t.sol
│   ├── TokenVesting.t.sol
│   └── MiniTreasureStaking.t.sol
├── script/
│   └── Deploy.s.sol            # Full-stack deployment script
└── lib/
    └── openzeppelin-contracts/ # OZ dependency
```

---

##  Security Considerations

### What's protected
-  **Reentrancy** — staking uses OpenZeppelin's `ReentrancyGuard`
-  **SafeERC20** — used for all token transfers (handles non-standard ERC-20s)
-  **Checks-effects-interactions** — state updated before external calls
-  **Capped supply** — hard limit enforced in `mint`
-  **Access control** — `Ownable` on privileged functions

### Known limitations (by design)
-  **Owner is trusted** — can mint, revoke vesting, and fund rewards
-  **No pause mechanism** — consider adding `Pausable` before mainnet
-  **Emergency penalties** accumulate in the staking contract with no withdrawal function
-  **Same token for staking + rewards** — for demo purposes; production should use separate reward token
-  **No upgradeability** — contracts are immutable (a feature, not a bug)

### Not audited
**This code has not been audited.** Do not deploy to mainnet with real value without a professional audit.

---

##  Tech Stack

- **[Foundry](https://getfoundry.sh/)** — build, test, and deploy toolchain
- **[OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)** v5.x — audited base contracts
- **Solidity** 0.8.24 — with built-in overflow checks

---

##  Roadmap

- [x] ERC-20 token with cap + burn
- [x] Multi-schedule vesting with cliffs
- [x] Tiered staking with lock periods
- [x] Emergency unstake with penalty
- [x] Full test suite
- [x] Deployment script
- [ ] Fuzz + invariant tests
- [ ] `AccessControl` with roles
- [ ] `Pausable` for emergency stops
- [ ] Penalty treasury withdrawal
- [ ] Frontend (wagmi + viem)
- [ ] Mainnet deployment

---

##  Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Ensure `forge test` passes
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push and open a PR

---

##  License

MIT — see [LICENSE](LICENSE) for details.

---

##  Acknowledgements

- [OpenZeppelin](https://www.openzeppelin.com/) for the battle-tested contract library
- [Foundry](https://getfoundry.sh/) for the best Solidity dev experience
- The broader Ethereum community for continuous inspiration

---

<p align="center">
  Built with LOVE using Foundry
</p>
```

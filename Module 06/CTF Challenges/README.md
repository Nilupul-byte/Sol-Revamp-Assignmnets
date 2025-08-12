# Secureum Challenges – Challenge 1 & Challenge 2

This repository contains Foundry-based Solidity tests demonstrating exploits against two vulnerable wrapped ETH contracts: **MagicETH** and **ModernWETH**.  
Each challenge includes a vulnerable contract, an exploit contract, and a test that proves the exploit works.

---

## 📂 Files Overview

### Challenge 1 – MagicETH
- **`Challenge1Test.sol`**  
  Contains the test `Challenge1Test` and the `Exploit` contract that targets `MagicETH`.
- **`MagicETH.sol`** (in `../src/1_MagicETH/`)  
  Vulnerable wrapped ETH implementation with a flawed withdrawal mechanism.

### Challenge 2 – ModernWETH
- **`Challenge2Test.sol`**  
  Contains the test `Challenge2Test` and the `Exploit` contract that targets `ModernWETH`.
- **`ModernWETH.sol`** (in `../src/2_ModernWETH/`)  
  Vulnerable wrapped ETH implementation with a broken `withdrawAll` logic.

---

## 🛠 How the Exploits Work

### Challenge 1 – MagicETH Exploit
**Goal:** Steal **1000 ETH** from the MagicETH contract to a `whitehat` address.

**Exploit Flow:**
1. Setup deposits 1000 ETH into `MagicETH` and assigns tokens to an exploiter.
2. The exploiter sends a small amount of tokens to `whitehat` to trigger a hook.
3. The `Exploit` contract:
   - Deposits 1000 ETH into MagicETH.
   - Calls the flawed `withdraw` logic to withdraw the full 1000 ETH.
   - Sends the stolen ETH to `whitehat`.

**Vulnerability:**  
The `withdraw` function likely miscalculates the redeemed amount or fails to validate token burns correctly, enabling the attacker to withdraw more ETH than they deposited.

---

### Challenge 2 – ModernWETH Exploit
**Goal:** Drain **1000 ETH** from ModernWETH to `whitehat` while keeping the initial 10 ETH.

**Exploit Flow:**
1. A whale deposits 1000 ETH into ModernWETH and transfers all tokens to `whitehat`.
2. `whitehat` deposits 10 ETH for an additional 10 tokens.
3. `whitehat` transfers all 1010 tokens to the `Exploit` contract.
4. The `Exploit` contract:
   - Calls `withdrawAll()`, which withdraws the **entire ETH balance** from ModernWETH.
   - Sends the stolen ETH (1000 ETH) to `whitehat`.

**Vulnerability:**  
The `withdrawAll` function sends the entire ETH balance to the caller without verifying that the burned tokens match the actual ETH backing.

---

## 🚀 Running the Tests

### Prerequisites
- [Foundry](https://book.getfoundry.sh/) installed
- Local environment with Forge configured

### Commands
Run the specific challenge test:
```bash
# Challenge 1
forge test --match-contract Challenge1Test -vvvv

# Challenge 2
forge test --match-contract Challenge2Test -vvvv

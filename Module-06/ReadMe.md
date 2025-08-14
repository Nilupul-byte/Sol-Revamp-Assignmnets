## How the Contract Works

The `TimeLockedWallet` contract is like a **digital safe** for ETH. Anyone can deposit ETH for a beneficiary, specifying:

- **Amount:** How much ETH to lock.
- **Unlock time:** When the beneficiary can claim.
- **Beneficiary:** Who will receive the ETH.

**Key Concepts:**

1. **Lock:**  
   Each deposit creates a unique `Lock` with: `amount`, `depositor`, `unlockTime`, and `claimed` status.

2. **Claim:**  
   Beneficiaries can claim their ETH **after the unlock time**, optionally sending it to a different recipient. A small **protocol fee** is deducted.

3. **Batch Claim:**  
   Allows a beneficiary to claim multiple matured locks at once. Ensures **state updates happen first** before transfers to prevent reentrancy.

4. **Reclaim:**  
   If a lock remains unclaimed after a **grace period**, the depositor can reclaim the ETH minus the fee.

5. **Protocol Fees:**  
   Collected fees are stored internally and can be withdrawn only by the admin.

6. **Pause Control:**  
   The contract can be paused to block all value-moving operations in emergencies.

7. **Security:**  
   - `nonReentrant` protects against reentrancy attacks.  
   - Direct ETH transfers are rejected to enforce proper lock creation.  
   - Custom errors save gas and provide clear failure reasons.

---

## Test Cases Explained

The tests are written using **Foundry** and simulate different scenarios:

1. **`testCreateLock()` – Lock Creation**  
   - Verifies a lock is stored correctly with the right depositor, beneficiary, amount, and unlock time.  
   - Confirms the lock is initially `claimed = false`.

2. **`testClaim()` – Single Claim by Beneficiary**  
   - Fast-forwards time to after the unlock time.  
   - Beneficiary claims the lock.  
   - Checks that ETH minus the protocol fee is received and the lock is marked as claimed.

3. **`testBatchClaim()` – Claim Multiple Locks**  
   - Creates multiple locks for the same beneficiary.  
   - Beneficiary claims all matured locks in one transaction.  
   - Checks that each lock is marked claimed and total ETH minus fees is correct.

4. **`testReclaim()` – Depositor Reclaims Unclaimed Lock**  
   - Creates a lock that is left unclaimed.  
   - Fast-forwards time past unlock + grace period.  
   - Depositor reclaims the ETH minus the protocol fee.  
   - Confirms the lock is marked claimed.

5. **`testWithdrawFees()` – Admin Withdraws Protocol Fees**  
   - After a claim, the protocol fee is stored internally.  
   - Admin withdraws the fees safely.  
   - Checks that fee balance is zeroed and ETH is received by the admin.

6. **`testAlreadyClaimedProtection()` – Prevent Double Claim**  
   - Beneficiary claims a lock successfully.  
   - Attempts a second claim on the same lock.  
   - Expects a revert with `AlreadyClaimed` error to prevent double claiming.

```bash
forge test --match-contract TimeLockedWalletTest -vvv

# Metana DeFi System

This project implements a yield-bearing **ERC-4626 vault** integrated with a custom **DeFi lending protocol**.  
Users can deposit MTN tokens, receive wrapped wMTN, and stake into an auto-compounding vault (aMTN) that grows as yield is harvested.

## Contracts
- **MetanaToken (MTN):** Base ERC20 asset token.
- **WrappedMetana (wMTN):** 1:1 wrapper minted/burned by the deposit contract.
- **DepositContract:** Handles MTN deposits, mints wMTN, and syncs rewards to the vault.
- **LendingProtocol:** Accepts MTN from the vault, generates interest, and allows harvesting.
- **AutoCompoundVault (aMTN):** ERC-4626 style vault for wMTN, issues shares, and auto-compounds yield.

## Workflow
1. Deposit MTN → receive wMTN via `DepositContract`.
2. Stake wMTN into `AutoCompoundVault` → receive aMTN shares.
3. Vault deploys MTN into `LendingProtocol`.
4. Periodically call `harvest()` → interest is pulled back, converted to wMTN, and increases vault assets.
5. Withdraw by redeeming aMTN → receive underlying wMTN.

## Notes
- Approvals are required before deposits (`approve` → `deposit`).
- Harvesting currently requires manual calls.
- Contracts are simplified for learning and testing with Remix.

# CrystalDAO Vault Challenge

## Overview

This repository contains a Solidity smart contract system that implements a **DAO Vault** pattern with signature-based transaction execution and a factory for deploying vault clones.

The vault allows an **owner** to authorize transaction executions off-chain using EIP-712 signatures, which are then executed on-chain by anyone presenting a valid signature. This pattern enables gasless meta-transactions and delegated transaction execution for DAO vaults.

---

## Contracts

- **DaoVaultImplementation**: The upgradeable vault implementation that holds funds and executes arbitrary calls authorized by the owner via signed messages.
- **FactoryDao**: A factory contract that deploys clones of the vault implementation for different owners.
- **IDaoVault**: Interface for interacting with the vault.

---

## Challenge

The goal is to **simulate a hack** scenario on the vault contract to withdraw 100 ether by providing a valid signature from the vault's owner.

The vault enforces:

- EIP-712 typed signatures for transaction authorization.
- A replay protection mechanism using nonces and signature tracking.
- Deadline for signature validity.

---

## Test Contract: `Challenge7Test`

The test:

- Deploys the factory and creates a new vault owned by `daoManager`.
- Funds the vault with 100 ether.
- Simulates a **whitehat** attacker who constructs a valid signature from the owner (`daoManager`) authorizing the transfer of 100 ether to the owner's address.
- Calls `execWithSignature` on the vault with the crafted signature and transaction data.
- Verifies that the ether balance of the `daoManager` has increased by 100 ether.

---

## How the Signature is Constructed

- Uses the same EIP-712 domain separator from the vault.
- Hashes the structured data with the exact `EXEC_TYPEHASH`.
- Includes the target address (`daoManager`), value (100 ether), empty calldata (`execOrder`) for simple ETH transfer, the nonce, and a deadline.
- Signs the resulting digest with the private key of `daoManager`.

---

## Setup and Run Tests

### Requirements

- [Foundry](https://github.com/foundry-rs/foundry) installed (`forge`, `cast`, etc).
- Solidity 0.8.x compiler.



## Module 08
# GameEconomy Deployment Script

This Foundry script deploys the **GameEconomyV1** and **GameEconomyV2** smart contracts to a blockchain network (e.g., Sepolia) and performs a sample currency purchase and balance upgrade.

## Features

- Deploys **GameEconomyV1** and **GameEconomyV2**.
- Buys a configurable number of in-game currency units at a cheaper price (`0.00001 ETH/unit`).
- Upgrades balances from V1 to V2 automatically.
- Logs purchased units and updated balances for verification.

## Environment Variables

- `PRIVATE_KEY`: Your wallet private key for deployment.  
- `ALCHEMY_KEY`: Your Alchemy API key for the target network.

## Usage

```bash
forge script script/Deploy.s.sol \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY \
  --private-key $PRIVATE_KEY \
  --broadcast

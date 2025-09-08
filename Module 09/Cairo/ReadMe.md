## Cairo Starknet Contract - Build & Deploy Guide

### Prerequisites
- Scarb, snforge, sncast, starknet-devnet installed (asdf recommended)
- Cairo toolchain compatible with Scarb edition 2024_07

Verify tools:
```bash
scarb --version
snforge --version
sncast --version
starknet-devnet --version
```

### Build
```bash
scarb build
```
Artifacts are generated under `target/dev` or `target/release`.

### Run tests
```bash
scarb test
```

### Local deployment (Devnet)
1) Start devnet (background):
```bash
starknet-devnet --seed 1 --lite-mode --timeout 1200 --port 5050 --host 127.0.0.1 > /tmp/devnet.log 2>&1 &
```

2) Configure sncast profile (already added in `snfoundry.toml`):
```toml
[sncast.devnet]
url = "http://127.0.0.1:5050/rpc"
accounts-file = "./accounts.json"
account = "devnet0"
wait-params = { timeout = 300, retry-interval = 10 }
```

3) Import a predeployed devnet account (example uses the first account printed by devnet):
```bash
sncast --profile devnet account import \
  --type open-zeppelin \
  --name devnet0 \
  --address 0x0260a8311b4f1092db620b923e8d7d20e76dedcc615fb4b6fdf28315b81de201 \
  --private-key 0x00000000000000000000000000000000c10662b7b247c7cecf7e8a30726cff12 \
  --class-hash 0x05b4b537eaa2399e3aa99c4e2e0208ebd6c71bc1467938cd52c798c601e43564 \
  --silent
```

4) Declare and deploy:
```bash
sncast --profile devnet declare --contract-name HelloStarknet
sncast --profile devnet deploy --class-hash <CLASS_HASH_FROM_DECLARE>
```

5) Interact:
```bash
sncast --profile devnet call --contract-address <CONTRACT_ADDRESS> --function get_balance
sncast --profile devnet invoke --contract-address <CONTRACT_ADDRESS> --function increase_balance --calldata 42
```

### Sepolia deployment
1) Configure profile (already added in `snfoundry.toml`):
```toml
[sncast.sepolia]
network = "sepolia"
accounts-file = "./accounts.json"
account = "sepolia0"
wait-params = { timeout = 600, retry-interval = 10 }
```

2) Create account (generates an address to fund):
```bash
sncast --profile sepolia account create --name sepolia0 --network sepolia
```
Copy the printed address and fund it with STRK (Sepolia). You can use a faucet or transfer from a wallet.

3) Deploy the funded account:
```bash
sncast --profile sepolia account deploy --name sepolia0 --network sepolia
```

4) Declare the contract on Sepolia:
```bash
sncast --profile sepolia declare --contract-name HelloStarknet --network sepolia
```
Note the printed `Class Hash`.

5) Deploy the contract:
```bash
sncast --profile sepolia deploy --class-hash <CLASS_HASH_FROM_DECLARE> --network sepolia
```

6) Interact on Sepolia:
```bash
sncast --profile sepolia call --contract-address <CONTRACT_ADDRESS> --function get_balance --network sepolia
sncast --profile sepolia invoke --contract-address <CONTRACT_ADDRESS> --function increase_balance --calldata 42 --network sepolia
```

### Troubleshooting
- If declaration fails on Sepolia with "class not declared" during deploy, wait until the declaration is "Accepted on L2":
```bash
sncast --profile sepolia tx-status <DECLARATION_TX_HASH> --network sepolia
```
- For devnet, ensure RPC is `http://127.0.0.1:5050/rpc` and devnet is running.

### Project layout
- Contract: `src/lib.cairo` (module `HelloStarknet`)
- Tests: `tests/test_contract.cairo`


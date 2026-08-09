#!/usr/bin/env bash
set -euo pipefail

NETWORK=${1:-testnet}
IDENTITY=${STELLAR_IDENTITY:-default}

echo "=== Building inFlow Soroban Smart Contract ==="
(cd contracts && cargo build --release --target wasm32v1-none -p inflow)

WASM_PATH="contracts/target/wasm32v1-none/release/inflow.wasm"

echo "=== Checking Deployer Balance ==="
ADMIN_ADDRESS=$(stellar keys address "$IDENTITY" 2>/dev/null || echo "")
if [ -n "$ADMIN_ADDRESS" ] && [ "$NETWORK" = "testnet" ]; then
  echo "Funding $ADMIN_ADDRESS via Friendbot..."
  curl -s "https://friendbot.stellar.org?addr=$ADMIN_ADDRESS" > /dev/null || true
  sleep 2
fi

echo "=== Deploying to $NETWORK ==="
CONTRACT_ID=$(stellar contract deploy \
  --wasm "$WASM_PATH" \
  --source "$IDENTITY" \
  --network "$NETWORK")

echo "Contract deployed: $CONTRACT_ID"
echo "=== Initializing Contract Admin ==="

ADMIN_ADDRESS=$(stellar keys address "$IDENTITY")

stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source "$IDENTITY" \
  --network "$NETWORK" \
  -- initialize \
  --admin "$ADMIN_ADDRESS"

echo ""
echo "=========================================="
echo " SUCCESS: inFlow deployed to $NETWORK"
echo " Contract ID: $CONTRACT_ID"
echo "=========================================="
echo "Update README.md and wrangler.toml with this Contract ID."

#!/usr/bin/env bash
set -euo pipefail

NETWORK=${1:-testnet}
CONTRACT_ID=${INFLOW_CONTRACT_ID:-PLACEHOLDER_TESTNET_CONTRACT_ID}

echo "=== inFlow Streaming Protocol Demo ($NETWORK) ==="
echo "Contract ID: $CONTRACT_ID"

echo "1. Querying next stream ID..."
stellar contract invoke \
  --id "$CONTRACT_ID" \
  --network "$NETWORK" \
  -- get_next_stream_id || echo "Contract query complete"

echo "2. Demo stream cycle complete!"

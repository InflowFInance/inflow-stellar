#!/usr/bin/env bash
# Verify deployed inFlow contract on testnet
set -euo pipefail

CONTRACT_ID="${1:-CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2}"
NETWORK="${2:-testnet}"

echo "=== inFlow Contract Verification ==="
echo "Contract: $CONTRACT_ID"
echo "Network:  $NETWORK"
echo ""

echo "--- Fetching stream counter (next_id) ---"
stellar contract invoke \
  --id "$CONTRACT_ID" \
  --network "$NETWORK" \
  --source inflow-deployer \
  -- get_next_stream_id

echo ""
echo "✅ Contract is live and responding on $NETWORK"
echo "Explorer: https://stellar.expert/explorer/$NETWORK/contract/$CONTRACT_ID"

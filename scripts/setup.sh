#!/usr/bin/env bash
set -euo pipefail

echo "=== Initializing inFlow Development Environment ==="

rustup target add wasm32v1-none
npm install

echo "Building contracts..."
(cd contracts && cargo build)

echo "Building SDK..."
(cd sdk && npm run build)

echo "=== Setup Complete! ==="

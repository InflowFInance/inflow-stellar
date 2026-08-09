# Deployment & Operator Runbook

This guide covers deployment procedures for inFlow smart contracts, Cloudflare Workers, and frontend applications on Stellar Testnet and Mainnet.

---

## 1. Prerequisites

- **Stellar CLI:** Installed via `cargo install stellar-cli --features opt`.
- **WASM Target:** `rustup target add wasm32v1-none`.
- **Wrangler CLI:** `npm install -g wrangler`.
- **Stellar Account:** Funded via Friendbot for Testnet.

---

## 2. Smart Contract Deployment (Testnet)

```bash
# 1. Build contract WASM
cd contracts
cargo build --release --target wasm32v1-none -p inflow

# 2. Deploy contract WASM
stellar contract deploy \
  --wasm target/wasm32v1-none/release/inflow.wasm \
  --source default \
  --network testnet

# 3. Initialize Contract Admin
stellar contract invoke \
  --id <DEPLOYED_CONTRACT_ID> \
  --source default \
  --network testnet \
  -- initialize \
  --admin <YOUR_PUBLIC_KEY>
```

Alternatively, run the automated script:
```bash
./scripts/deploy.sh testnet
```

---

## 3. Cloudflare Worker Relay Deployment

```bash
cd workers

# 1. Set required environment secrets
wrangler secret put TREASURY_SECRET_KEY
wrangler secret put EMAIL_SENDER_API_KEY
wrangler secret put OTP_SIGNING_SECRET
wrangler secret put KEYPAIR_ENCRYPTION_KEY

# 2. Deploy worker
wrangler deploy
```

---

## 4. Mainnet Deployment Checklist

- [ ] Smart contract audit complete
- [ ] Treasury account funded with minimum XLM base reserve
- [ ] Worker environment variables switched to `STELLAR_NETWORK = "mainnet"`
- [ ] Network passphrases set to `Public Global Stellar Network ; September 2015`
- [ ] Frontend meta tags updated with Mainnet Contract ID and Worker URL

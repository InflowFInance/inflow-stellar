# `inflow-workers`

Cloudflare Worker relay for inFlow on Stellar.

## Endpoints

- `POST /send-otp` — Generate and email OTP code
- `POST /verify-otp` — Verify OTP, derive Ed25519 keypair via HKDF, return public key
- `POST /fee-bump` — Wrap user transaction XDR in a `fee_bump` envelope signed by Treasury
- `GET /stream-info?id=X` — Fetch metadata for active streams
- `POST /store-stream-secret` — Store secret hash mapping for email-gated claim links
- `POST /trigger-sponsorship` — Fund Testnet accounts via Friendbot

## Deployment

```bash
npm install
wrangler deploy
```

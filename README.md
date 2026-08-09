# inFlow for Stellar

get paid by the second. Your salary streams in real time on Stellar.

🌍 **Africa's First Salary Streaming Protocol — now on Stellar**

The first platform where your salary hits your pocket the moment you work — second by second — on a network built for financial inclusion.

---

## The Problem

Across Africa, delayed wages are an epidemic. An employee works for 30 days, hands over their full labour, and waits — hoping their employer pays on time, in full, at all. The ILO has formally described wage debt as "another African epidemic." 93% of Nigeria's workforce has no formal wage contract. No receipts. No proof. No legal recourse.

But there's a second, quieter problem: when an employer does lock funds for salary, that capital sits completely idle until payday. A 1,000 USDC salary budget locked for 30 days earns nothing. The worker waits, and the money sleeps.

## Why Stellar

Stellar isn't just another chain — it's the right chain for this use case:

- **Sub-cent fees** — critical for emerging markets where every cent counts
- **3-5 second finality** — payments feel instant
- **USDC on Stellar is native and cheap to move** — no wrapped tokens, no bridging
- **Stellar's mission is financial inclusion** — inFlow's exact target market

EVM chains charge dollars per transaction. On Stellar, streaming a salary costs fractions of a cent. That difference isn't cosmetic — it's the difference between a product that works for African workers and one that doesn't.

## How It Works

### For Employers (Payers)
1. Connect email — no wallet needed
2. Enter budget + duration (e.g., 500 USDC over 30 days)
3. Funds are locked in a Soroban smart contract
4. Share a payment link with your worker

### For Workers (Recipients)
1. Open the payment link — no signup required
2. Verify email via OTP
3. Watch earnings tick up per-second in real time
4. Withdraw earned funds anytime — no waiting for payday

### The Flow
```
create_stream()     → funds locked in Soroban contract
      |
      | (optional) claim_stream(secret) ← email-gated streams
      v
[streaming]         → time passes, balance accrues to recipient
      |
      |--→ withdraw()        ← recipient pulls earned amount anytime
      |--→ cancel_stream()   ← sender or recipient cancels, both get their share
      v
[completed]         → stopTime reached, all funds withdrawable
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter Web / Mobile                  │
│                  (Flutter Web + StellarBridge.js)            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                   Cloudflare Worker Backend                 │
│  ┌────────────┬────────────┬────────────┬─────────────────┐ │
│  │ Email OTP  │ Fee Bump  │ Stream     │ Friendbot       │ │
│  │ (EmailJS)  │ Sponsor   │ Relay      │ Sponsorship     │ │
│  └────────────┴────────────┴────────────┴─────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                  Soroban Smart Contract (Rust)               │
│  • create_stream / claim_stream / withdraw / cancel_stream  │
│  • Persistent storage with TTL management                   │
│  • Time-based unlocked balance math                         │
│  • Email-gated claim flow (SHA-256 hash verification)       │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                      Stellar Network                         │
│              (Testnet → Mainnet when ready)                  │
└─────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Smart Contract | Soroban / Rust |
| SDK | TypeScript (`@inflow/sdk`) |
| Backend | Cloudflare Workers |
| Email Delivery | EmailJS |
| Frontend (Web) | Flutter Web + StellarBridge.js |
| Frontend (Mobile) | Flutter (iOS + Android) |
| Hosting | Firebase Hosting |
| Auth | Email OTP + deterministic keypair derivation |

## Key Features

- **Gasless UX** — users never pay transaction fees; the Worker sponsors all on-chain operations via `fee_bump`
- **Email-only onboarding** — no seed phrases, no wallet apps, no complexity
- **Email-gated streams** — claim links secured by SHA-256 hash verification
- **TTL-safe storage** — Soroban persistent storage with automatic TTL extension on every read and write
- **Live earnings ticker** — per-second balance updates in the UI
- **QR claim links** — shareable payment links that recipients can scan
- **Biometric auth** — local biometric confirmation before withdrawals on mobile

## Local Development

### Prerequisites
- Rust 1.97.1+ with `wasm32v1-none` target
- Node.js 18+
- Flutter 3.24+
- Firebase CLI
- Wrangler CLI

### Setup

```bash
# Clone and enter
git clone https://github.com/InflowFInance/inflow-stellar.git
cd inflow-stellar

# Install Rust dependencies
rustup target add wasm32v1-none

# Build Soroban contract
cd contracts/inflow
cargo test
cargo clippy -- -D warnings
cargo build --target wasm32v1-none

# Install SDK dependencies
cd ../../sdk
npm install
npm run build

# Install Worker dependencies
cd ../workers
npm install
npm run build

# Run Flutter Web
cd ../apps/web
flutter pub get
flutter run -d chrome
```

## Security

**This project is currently unaudited.** Do not use with significant funds until a formal security audit is complete.

To report a vulnerability, please use GitHub's private vulnerability reporting feature or email security@inflow-stellar.dev.

## Roadmap

**Near Term**
- Complete Soroban streaming contract with full test coverage
- TypeScript SDK shipped to npm
- Flutter Web on Stellar Testnet
- Flutter Mobile (Android APK + iOS TestFlight)
- Email-only onboarding working end-to-end
- Testnet demo live

**Medium Term**
- Stellar Mainnet deployment
- Multi-token support (XLM + USDC)
- Stream pause/resume functionality
- SEP-30 Social Recovery for true self-custody email auth
- On-chain stream indexer

**Long Term**
- Blend Protocol integration for yield on employer funds while streaming
- DAO governance for protocol parameters
- Cross-chain bridge (Stellar ↔ Base)
- Enterprise employer dashboard (bulk streams, CSV import)
- Native app store distribution (Google Play + App Store)

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before submitting PRs.

## License

Apache-2.0 — see [LICENSE](LICENSE)

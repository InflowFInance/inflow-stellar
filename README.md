# inFlow for Stellar
> **Real-time salary streaming on Stellar.** *Your work ends. Your pay starts.*

[![CI](https://github.com/InflowFinance/inflow-stellar/actions/workflows/ci.yml/badge.svg)](https://github.com/InflowFinance/inflow-stellar/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Stellar](https://img.shields.io/badge/Stellar-Soroban-purple.svg)](https://stellar.org)

inFlow is an open-source protocol for streaming salaries, wages, and recurring payments per second on the Stellar network. Originally built for emerging markets (Africa), inFlow allows workers to stream their earned pay in real time and withdraw USDC anytime with zero transaction fees and email-only onboarding.

---

## 🏗️ Architecture Overview

```
                          ┌───────────────────────────┐
                          │   User (Email OTP Only)   │
                          └─────────────┬─────────────┘
                                        │
                                        │ HTTP API
                                        v
                          ┌───────────────────────────┐
                          │ Cloudflare Worker Relay   │
                          │ - HKDF Keypair Custody    │
                          │ - fee_bump Transaction    │
                          │   Sponsorship             │
                          └─────────────┬─────────────┘
                                        │
                                        │ Soroban RPC
                                        v
                          ┌───────────────────────────┐
                          │  InFlow Soroban Contract  │
                          │  - Persistent Storage     │
                          │  - Touch-on-Read TTL      │
                          │  - SHA-256 Secret Claim    │
                          └─────────────┬─────────────┘
                                        │
                                        v
                          ┌───────────────────────────┐
                          │    USDC Token Contract    │
                          │  (Stellar Asset Contract) │
                          └───────────────────────────┘
```

---

## 🚀 Key Features

- ⚡ **Per-Second Streaming:** Earnings accrue dynamically based on time elapsed (`rate_per_second = deposit / duration`).
- 🔐 **Gasless UX (`fee_bump`):** All user transactions are wrapped in Stellar `fee_bump` envelopes. The Cloudflare Worker treasury pays all fees.
- 📧 **Email-Only Onboarding:** Deterministic Ed25519 keypair derivation via HKDF with server-side master key. Users never manage seed phrases.
- ✉️ **Email-Gated Claim Links:** Employers can stream to email recipients before they join. Recipients claim funds with a SHA-256 secret link.
- 🛡️ **Soroban Storage TTL Defense:** Touch-on-read TTL extension on every persistent storage access prevents state archival.
- 📱 **Cross-Platform:** Shared Flutter codebase for Web and Mobile (iOS & Android).

---

## 🛠️ Technology Stack

| Component | Technology | Description |
|---|---|---|
| **Smart Contract** | Rust (`wasm32v1-none`) | Soroban smart contract using persistent storage and events |
| **SDK** | TypeScript | `@inflow/sdk` thin client wrapper over Soroban RPC |
| **Backend** | Cloudflare Workers | Serverless relay for email OTP, keypair derivation, and `fee_bump` |
| **Web App** | Flutter Web | Responsive web app using custom `StellarBridge.js` interop |
| **Mobile App** | Flutter Mobile | Cross-platform mobile app with biometric auth & QR scanner |

---

## 📂 Repository Layout

```
inflow-stellar/
├── contracts/             # Soroban smart contract (Rust workspace)
│   └── inflow/            # Core contract implementation
├── sdk/                   # TypeScript SDK package (@inflow/sdk)
├── workers/               # Cloudflare Worker backend API
├── apps/web/              # Flutter Web frontend app
├── mobile/                # Flutter Mobile (iOS & Android) app
├── scripts/               # Deployment and demo automation scripts
├── docs/                  # System documentation & runbooks
└── .github/               # CI workflows & issue templates
```

---

## 📑 Deployed Contracts

| Network | Contract Address / ID | Status |
|---|---|---|
| **Stellar Testnet** | `PLACEHOLDER_TESTNET_CONTRACT_ID` | Pending Deploy |
| **Stellar Mainnet** | `PLACEHOLDER_MAINNET_CONTRACT_ID` | Planned |

---

## 🚦 Quick Start

### Prerequisites
- Rust stable (`rustup target add wasm32v1-none`)
- Node.js 20+ & npm 10+
- Flutter 3.x
- Stellar CLI (`cargo install stellar-cli --features opt`)

### Bootstrap
```bash
git clone https://github.com/InflowFinance/inflow-stellar.git
cd inflow-stellar
npm install
cd contracts && cargo build
```

---

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on code standards, testing requirements, and submission guidelines.

---

## 📄 License

Distributed under the Apache 2.0 License. See [LICENSE](LICENSE) for more information.

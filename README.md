# ⚡ inFlow Stellar Protocol

[![Live Web App](https://img.shields.io/badge/Live%20App-inflowfinance.web.app-F59E0B?style=for-the-badge&logo=google-chrome&logoColor=white)](https://inflowfinance.web.app)
[![Network](https://img.shields.io/badge/Network-Stellar%20Testnet-7C3AED?style=for-the-badge&logo=stellar&logoColor=white)](https://stellar.expert/explorer/testnet/contract/CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2)
[![Contract](https://img.shields.io/badge/Soroban%20Contract-CCCFBM...QJGX62W2-00D37F?style=for-the-badge&logo=rust&logoColor=white)](https://stellar.expert/explorer/testnet/contract/CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

> **Real-time salary streaming for Africa's workforce. No bank. No delay. Just email.**

inFlow is a decentralized, real-time wage streaming protocol built on Stellar and Soroban smart contracts. It enables employers to deposit USDC salaries that unlock continuously per second, allowing employees to access their earned wages on demand without waiting for 30-day pay cycles or incurring predatory loan fees.

---

## 🎯 The Problem in Africa

- **77%** of African workers live paycheck to paycheck.
- **31+ Days** average wait time to receive monthly salary earnings.
- **$5B+** lost annually across the continent to wage debt, payroll delays, and expensive micro-loans.
- **0s Delay** with inFlow. Money streams second-by-second directly to workers.

---

## ⚡ How It Works

```mermaid
flowchart LR
    A[Employer Deposit] -->|Lock USDC| B[Soroban Contract]
    B -->|Stream / sec| C[Per-Second Unlocking]
    C -->|Email Claim Link| D[Worker Wallet]
    D -->|Fee-Bump Sponsored| E[Withdraw USDC Anytime]
```

1. **Sign in with Email**: Passwordless, non-custodial wallet keypair derived securely via HKDF from authenticated sessions.
2. **Employer Deposits USDC**: Employer specifies recipient email, deposit amount in USDC, and streaming duration (e.g. 30 days).
3. **Per-Second Salary Stream**: Soroban smart contract locks funds and unlocks salary micro-payments down to the second.
4. **Open Secure Claim Link**: Employee receives an email notification with a direct claim link—salary is already streaming before initial sign-in.
5. **Collect Earnings Anytime**: Employee collects accumulated earnings on demand into their wallet with zero gas fees sponsored via Stellar `fee_bump`.

---

## 🛠️ Technology Stack

| Layer | Technology | Function |
| :--- | :--- | :--- |
| **Smart Contracts** | Soroban / Rust | On-chain vault locking, per-second rate math, automated stream state management |
| **Frontend App** | Flutter Web / Dart | Responsive UI/UX with real-time earnings tickers, glassmorphism design, and PWA capabilities |
| **Relay Service** | Cloudflare Workers | HKDF key derivation, email OTP verification, and Stellar `fee_bump` gas sponsorship |
| **Blockchain** | Stellar Network | Sub-5s finality, micro-cent transaction fees, and native Circle USDC settlement |

---

## 📜 Soroban Smart Contract Info

- **Contract ID**: `CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2`
- **Network**: Stellar Testnet & Mainnet Ready
- **Explorer Link**: [View on Stellar Expert](https://stellar.expert/explorer/testnet/contract/CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2)

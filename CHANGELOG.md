# Changelog

All notable changes to the **inFlow for Stellar** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0-testnet] - 2026-08-10

### Added
- Soroban contract deployed and initialized on Stellar Testnet.
- Contract ID: `CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2`
- Deployer: `GBFYGDEXSLR23E2R5DHFEMDKWVC5HDCQVD44J4TPREGMMCJ7VNDWY6TG`
- Explorer: https://stellar.expert/explorer/testnet/contract/CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2

## [0.1.0] - 2026-08-09

### Added
- Initial Soroban streaming smart contract (`contracts/inflow`) in Rust (`wasm32v1-none`).
- Touch-on-read storage TTL management strategy (`storage.rs`).
- Time-based streaming math (`unlocked_balance`, `available_to_withdraw`, `cancellation_split`).
- SHA-256 secret-gated email claim mechanism (`claim_stream`).
- TypeScript SDK (`@inflow/sdk`) with `InFlowClient`.
- Cloudflare Worker relay (`workers/`) for email OTP, HKDF keypair custody, and `fee_bump` wrapping.
- Custom JS bridge (`StellarBridge.js`) for Flutter Web interop.
- Adapted Flutter Web frontend app (`apps/web/`).
- Native Flutter Mobile app (`mobile/`) with biometric auth and QR code claim link scanner.
- Complete GitHub Actions CI workflow for Rust, TypeScript SDK, and Workers.
- Open Source health documentation (`README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `GOVERNANCE.md`, `SECURITY.md`, `LICENSE`).

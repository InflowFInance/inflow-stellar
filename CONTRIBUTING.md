# Contributing to inFlow for Stellar

Thank you for investing time in contributing to inFlow! This document provides guidelines and instructions for building, testing, and submitting code to the repository.

---

## 🎯 Ways to Contribute

- **Smart Contract Improvements:** Gas optimization, storage efficiency, or new streaming parameters.
- **SDK & Developer Experience:** Adding helper utilities or improving TypeScript interfaces.
- **Frontend & Mobile UI:** Enhancing user experience, ticker animations, or responsiveness.
- **Backend & Relayers:** Security enhancements, rate-limiting, or fee-bump optimizations.
- **Documentation & Runbooks:** Clarifying deployment procedures or architecture docs.

---

## 💻 Development Setup

### Prerequisites
- **Rust Toolchain:** Managed via `rust-toolchain.toml` (target: `wasm32v1-none`).
- **Node.js:** v20 or higher.
- **Flutter:** 3.x for web and mobile development.
- **Stellar CLI:** For contract deployment and invocation.

### Initial Build Steps
```bash
git clone https://github.com/InflowFinance/inflow-stellar.git
cd inflow-stellar
npm install
cd contracts && cargo build
```

---

## 🧪 Testing Guidelines

Before opening a pull request, ensure all validation checks pass:

```bash
# 1. Contract formatting and linting
cd contracts
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test

# 2. SDK build and test
cd ../sdk
npm run build
npm test

# 3. Cloudflare Worker build
cd ../workers
npm run build
```

---

## 📝 Commit Message Conventions

We use structured commit messages to maintain a clean git history:

- `feat(contracts): add TTL touch-on-read storage helper`
- `fix(sdk): handle zero deposit remainder calculations`
- `test(contracts): add secret claim verification unit tests`
- `docs: update deployment runbook for testnet`
- `ci: add GitHub Actions WASM build step`

---

## 🔒 Security Vulnerabilities

Please do not open public GitHub issues for security vulnerabilities. Refer to [SECURITY.md](SECURITY.md) for instructions on confidential disclosure.

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the [Apache 2.0 License](LICENSE).

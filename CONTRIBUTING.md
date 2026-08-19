# Contributing to inFlow Stellar

Thank you for your interest in contributing to **inFlow Stellar**! We are building open-source infrastructure for real-time salary streaming across Africa on Stellar and Soroban.

This document outlines the workflow and guidelines for open-source maintainers and contributors.

---

## 🤝 Code of Conduct

We expect all contributors to adhere to our standards of respectful, inclusive, and professional communication.

---

## 🛠️ How to Contribute

### 1. Find or Open an Issue
- Browse open GitHub Issues labeled `good-first-issue` or `enhancement`.
- Request assignment on an issue before starting work to avoid duplicate effort.
- Unassigned draft Pull Requests may be closed.

### 2. Fork & Clone Repository
```bash
git clone https://github.com/InflowFInance/inflow-stellar.git
cd inflow-stellar
```

### 3. Create a Feature Branch
Use descriptive branch prefixes:
- `feat/feature-name` for new features
- `fix/bug-name` for bug fixes
- `docs/doc-name` for documentation updates
- `test/test-name` for tests

```bash
git checkout -b feat/my-new-feature
```

### 4. Code Quality & Standards
- **Flutter Web**: Follow the official Flutter style guide. Run `flutter analyze` before committing.
- **Soroban Contracts**: Enforce safety patterns in Rust, avoid panic conditions, and document public functions with `///` rustdoc.
- **Commit Messages**: Follow standard conventional commits format (e.g. `feat: ...`, `fix: ...`, `docs: ...`, `refactor: ...`).

### 5. Run Automated Analysis & Tests
```bash
cd apps/web
flutter analyze
flutter test
```

### 6. Submit a Pull Request
- Push your feature branch: `git push origin feat/my-new-feature`
- Open a Pull Request against `main`.
- Link relevant GitHub issues in the PR description (e.g. `Closes #12`).
- Provide screenshots or GIF recordings for UI changes.

---

## ⚡ Architecture Overview for Contributors

- **Frontend**: Flutter Web in `apps/web/lib/main.dart` with `@JS('window.StellarBridge')` JavaScript interop.
- **Contract**: Soroban Rust contract in `contract/src/lib.rs`.
- **Relay**: Cloudflare Worker relay handling HKDF non-custodial session key derivation and `fee_bump` gas sponsorship.

---

## 💬 Getting Help

If you have questions or get stuck:
- Open a discussion in GitHub Discussions.
- Tag maintainers `@stayzappy` or `@Dominion116` on your PR.

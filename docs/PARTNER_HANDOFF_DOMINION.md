# 🤝 Contributor Handoff Guide for @Dominion116
## inFlow Stellar Protocol — Open Source Development Roadmap

Welcome to the **inFlow Stellar** team! This guide contains everything you need to contribute predictably without needing daily check-ins.

---

## 🛠️ Quick Setup (One-Time)

1. Clone the repository:
   ```bash
   git clone https://github.com/InflowFInance/inflow-stellar.git
   cd inflow-stellar
   ```
2. Make sure your git email matches your GitHub account:
   ```bash
   git config user.email "your-email@example.com"
   git config user.name "Dominion116"
   ```
3. Test local build:
   ```bash
   cd apps/web
   flutter pub get
   flutter analyze
   ```

---

## 🔄 Standard PR Workflow for Every Task

For each task below, follow these exact steps:

1. **Create a new branch**:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b docs/your-task-name   # or feat/your-task-name
   ```
2. **Make your changes** in the specified file.
3. **Run analysis**:
   ```bash
   cd apps/web && flutter analyze
   ```
4. **Commit with clean message**:
   ```bash
   git add .
   git commit -m "docs: add SECURITY.md disclosure policy"
   git push origin docs/your-task-name
   ```
5. **Open a Pull Request** on GitHub against `main`:
   - Title: `docs: add SECURITY.md disclosure policy`
   - Tag `@stayzappy` as reviewer.

---

## 📅 Schedule & Tasks (1 Task Every 2–3 Days)

### 📌 Task 1 (Aug 21): Add SECURITY.md Disclosure Policy
- **File**: `SECURITY.md` (root directory)
- **Goal**: Create a standard `SECURITY.md` file with a security contact email (`dev@inflow.finance`), vulnerability reporting guidelines, and a 48-hour response SLA.

### 📌 Task 2 (Aug 23): Add FAQ Section to README.md
- **File**: `README.md`
- **Goal**: Add a 5-question FAQ section at the bottom of `README.md` covering:
  - Is inFlow safe?
  - Do users need crypto knowledge?
  - What happens if an employer cancels a stream?
  - What is fee_bump sponsorship?
  - What is Soroban?

### 📌 Task 3 (Aug 25): Add Rustdoc Comments in Soroban Contract
- **File**: `contract/src/lib.rs` (or `contract/CONTRACT.md`)
- **Goal**: Add clear doc comments (`///`) above public contract structs and functions explaining parameter constraints.

### 📌 Task 4 (Aug 28): Add Unit Test for Stream Data Math
- **File**: `apps/web/test/stream_math_test.dart`
- **Goal**: Create a simple Dart test file verifying `unlockedAmount` rate per second calculations for 30-day streams.

### 📌 Task 5 (Aug 31): Add Inline Code Comments across main.dart
- **File**: `apps/web/lib/main.dart`
- **Goal**: Add clean inline header comments above major sections (`// SECTION 1: THEME & CONSTANTS`, `// SECTION 2: WIDGET UTILITIES`, etc.).

### 📌 Task 6 (Sep 3): Improve pubspec.yaml Metadata
- **File**: `apps/web/pubspec.yaml`
- **Goal**: Ensure package version, homepage link (`https://inflowfinance.web.app`), repository link, and description are fully populated.

### 📌 Task 7 (Sep 6): Add CHANGELOG.md Entry
- **File**: `CHANGELOG.md`
- **Goal**: Create `CHANGELOG.md` summarizing features shipped in `v0.1.0`.

---

## 💡 Support
If you get stuck on any task, open a draft PR or leave a comment on the GitHub Issue and tag `@stayzappy`.

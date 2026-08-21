# Security Policy

inFlow for Stellar handles real value: Soroban smart contracts, a fee-sponsoring relay, and
custodial key derivation for email-claimed streams. We take security reports seriously and
appreciate the work of researchers who help keep users safe.

---

## 📦 Supported Versions

| Version | Status | Security Fixes |
| --- | --- | --- |
| `0.1.x` (Testnet) | ✅ Actively developed | Yes |
| `< 0.1.0` | ❌ Pre-release prototypes | No |

Only the latest `main` branch and the most recent tagged release receive security fixes.

---

## 🔒 Reporting a Vulnerability

**Please do not open a public GitHub issue, pull request, or discussion for security
vulnerabilities.** Public disclosure before a fix is available puts users at risk.

Use one of these private channels instead:

1. **GitHub Private Vulnerability Reporting** (preferred) — open the repository's
   **Security → Report a vulnerability** tab.
2. **Email** — `dev@inflow.finance` (alias: `security@inflow.finance`)

If your report is sensitive, say so in the first message and we will arrange an encrypted
channel before you share details.

### What to include

A good report helps us reproduce and fix the issue quickly. Where possible, include:

1. **Description** — the vulnerability class and the component affected
   (Soroban contract, TypeScript SDK, Cloudflare Worker relay, Flutter web/mobile app).
2. **Reproduction steps** — a minimal proof-of-concept, failing test, transaction hash,
   or contract invocation that demonstrates the issue.
3. **Impact assessment** — what an attacker can achieve (fund loss, unauthorized
   withdrawal or cancellation, key/OTP compromise, denial of service, data exposure).
4. **Environment** — network (Testnet/Mainnet), contract ID, commit SHA or release tag,
   and any relevant configuration.
5. **Contact preference** — how you would like to be credited, if at all.

---

## ⏱️ Response Targets

| Stage | Target |
| --- | --- |
| Acknowledgement of your report | **Within 48 hours** |
| Initial triage and severity assessment | Within 5 business days |
| Fix or documented mitigation for critical issues | Within 14 days |
| Public advisory after a fix ships | Within 90 days of the report |

We will keep you updated on progress and let you know if we need more time. If you have not
received an acknowledgement within 48 hours, please follow up by email in case the original
message was filtered.

---

## 🤝 Coordinated Disclosure

- We ask that you give us a reasonable opportunity to ship a fix before disclosing publicly.
- We will publish a GitHub Security Advisory and a `CHANGELOG.md` entry once a fix is released.
- With your permission, we will credit you in the advisory.
- We do not currently run a paid bug bounty program.

### Safe harbour

We will not pursue or support legal action against researchers who, in good faith:

- test only against **Stellar Testnet** or their own accounts and deployments,
- avoid privacy violations, data destruction, and service degradation for other users,
- avoid social engineering, phishing, and physical attacks against inFlow or its users, and
- report findings promptly and privately through the channels above.

---

## 🎯 Scope

**In scope**

- `contracts/inflow` — Soroban streaming contract logic, storage TTL handling, and
  streaming math (`unlocked_balance`, `available_to_withdraw`, `cancellation_split`).
- `sdk/` — the `@inflow/sdk` TypeScript client.
- `workers/` — the Cloudflare Worker relay: email OTP flow, HKDF keypair derivation and
  custody, and `fee_bump` transaction sponsorship.
- `apps/web/` and `mobile/` — client applications, including the `StellarBridge.js` interop
  layer and claim-link handling.

**Out of scope**

- Vulnerabilities in third-party dependencies without a demonstrated impact on inFlow
  (please report those upstream, and let us know so we can bump the dependency).
- Issues in Stellar Core, Horizon, Soroban RPC, or wallet software we do not maintain.
- Missing security headers, rate limiting, or best-practice findings with no exploitable
  impact, and automated scanner output without a working proof-of-concept.
- Spam, volumetric DDoS, and self-inflicted issues (for example, leaking your own secret key
  or claim link).

---

## 🛡️ Smart Contract Disclaimer

The inFlow Soroban smart contract is open source. While unit test coverage is comprehensive,
the contract has **not yet undergone a third-party security audit**. The current deployment
targets Stellar **Testnet**. Exercise caution when deploying significant funds to production
and review [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the trust assumptions of the
relay and email-claim custody model.

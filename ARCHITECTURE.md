# System Architecture — inFlow for Stellar

This document details the architectural design, component boundaries, and security model of inFlow on the Stellar network.

---

## 🏛️ High-Level System Topology

inFlow consists of five distinct components:

1. **Soroban Smart Contract (`contracts/inflow`):** On-chain logic enforcing payment stream creation, time-based balance accrual, claims, withdrawals, cancellations, and storage TTL extensions.
2. **TypeScript SDK (`sdk/`):** Type-safe library for building, simulating, and submitting Soroban contract invocations.
3. **Cloudflare Worker Backend (`workers/`):** Serverless API managing email OTP authentication, deterministic HKDF keypair derivation, and transaction wrapping in Stellar `fee_bump` envelopes.
4. **Flutter Web App (`apps/web/`):** Web application interfacing with the Stellar network via custom `StellarBridge.js`.
5. **Flutter Mobile App (`mobile/`):** Native iOS and Android app communicating directly with the Worker relay via HTTP.

---

## ⏱️ Real-Time Streaming Mathematics

Earnings accrue dynamically every second according to the formula:

$$\text{unlockedBalance}(t) = \begin{cases} 
0 & t \le t_{\text{start}} \\
\text{deposit} & t \ge t_{\text{stop}} \\
(t - t_{\text{start}}) \times \text{ratePerSecond} & t_{\text{start}} < t < t_{\text{stop}}
\end{cases}$$

where:
$$\text{ratePerSecond} = \frac{\text{deposit}}{t_{\text{stop}} - t_{\text{start}}}$$

- Deposits must be perfectly divisible by duration ($t_{\text{stop}} - t_{\text{start}}$) to eliminate rounding dust.
- Withdrawable balance is calculated as $\text{unlockedBalance}(t) - \text{withdrawnAmount}$.

---

## 🛡️ Soroban Storage TTL Strategy

Soroban persistent storage entries expire and get archived if their Time-To-Live (TTL) ledger threshold is crossed. To prevent stream loss:

1. **Touch-on-Read Pattern:** Every `persistent().get()` call in the contract automatically calls `extend_ttl()`.
2. **Write Extension:** Every `persistent().set()` call extends storage TTL immediately.
3. **Public Extension Endpoint:** The `extend_stream_ttl(stream_id)` function allows anyone (e.g. indexers or maintenance bots) to extend an active stream's TTL.

Constants:
- `TTL_THRESHOLD`: 10,000 ledgers (~13.8 hours at 5s/ledger)
- `TTL_EXTEND_TO`: 6,307,200 ledgers (~1 year)

---

## 🔐 Gasless UX (`fee_bump`) & Auth Model

```
 ┌──────────────┐     1. Build & Sign Tx      ┌──────────────────────────┐
 │ User Client  │ ──────────────────────────> │ Cloudflare Worker Relay  │
 └──────────────┘                             └────────────┬─────────────┘
                                                           │ 2. Wrap in fee_bump
                                                           │    (Treasury pays)
                                                           v
                                              ┌──────────────────────────┐
                                              │      Stellar Network     │
                                              └──────────────────────────┘
```

1. **Email OTP:** User signs in with email; Worker derives deterministic Ed25519 seed via HKDF using server-side master key + email hash.
2. **Inner Transaction:** Client builds contract call and signs it using derived keypair.
3. **Outer Envelope:** Worker wraps the signed transaction in a `fee_bump` envelope signed by the Treasury secret key.
4. **Submission:** Treasury covers all network gas fees. User experiences zero gas friction.

## Streaming Math Reference

```
deposit_amount = total USDC locked by employer
duration_seconds = stream end_time - start_time
rate_per_second = deposit_amount / duration_seconds

# At any point in time t:
elapsed = min(current_time, end_time) - start_time
unlocked_balance = rate_per_second * elapsed - withdrawn_amount

# On cancellation at time t:
employer_refund = rate_per_second * (end_time - current_time)
recipient_claimable = rate_per_second * elapsed - withdrawn_amount
```

All arithmetic uses i128 with fixed-point scaling to avoid floating-point rounding errors in Soroban.

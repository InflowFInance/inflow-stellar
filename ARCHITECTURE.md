# Architecture

inFlow for Stellar is a real-time salary streaming protocol.

## System Components

| Component | Location | Purpose |
|---|---|---|
| contracts/inflow | Rust/Soroban | Core streaming logic, stream storage |
| sdk/ | TypeScript | Thin client for contract invocation |
| apps/web/ | Flutter Web | Browser-based UI |
| mobile/ | Flutter | iOS + Android mobile app |
| workers/ | Cloudflare Workers | Email OTP, keypair custody, fee_bump |

## Trust Model

The contract is the source of truth. Frontend and SDK are conveniences, not authorities.

## Stream Lifecycle

```
create_stream()     → stream exists, funds held in contract
     |
     | (optional) claim_stream(secret)   ← email-gated streams only
     v
[streaming]         → time passes, balance accrues to recipient
     |
     |--→ withdraw()        ← recipient pulls earned amount anytime
     |--→ cancel_stream()   ← sender or recipient cancels, both get their share
     v
[completed]         → stopTime reached, all funds withdrawable
```

## Authentication Flow

1. User enters email → POST /send-otp → Worker sends OTP email
2. User enters OTP → POST /verify-otp → Worker verifies, returns Stellar public key
3. Worker derives deterministic Ed25519 keypair from email using HKDF + server secret
4. All subsequent txns: user signs inner tx, worker wraps in fee_bump (treasury pays fee)
5. User never sees seed phrase, never pays a fee

## Fee Sponsorship (Gasless UX)

```
User signs inner transaction XDR → sends to Worker
Worker wraps with fee_bump using treasury keypair → submits to Stellar
Treasury pays the fee
User pays nothing
```

## Soroban Storage TTL (CRITICAL)

Soroban persistent storage entries are archived if their TTL expires.
Archived data causes silent payment failures — streams become inaccessible.

Defense-in-depth TTL strategy:
1. Write path: extend_ttl() called after every persistent().set()
2. Read path: extend_ttl() called after every persistent().get() (touch-on-read)
3. Public function: extend_stream_ttl(stream_id) callable by anyone

Constants:
- TTL_THRESHOLD = 10_000 ledgers (~13.8 hours at 5s/ledger) — renew if below
- TTL_EXTEND_TO = 6_307_200 ledgers (~1 year) — target when renewing

## Soroban Authorization

Every privileged operation calls address.require_auth():
- create_stream → sender.require_auth()
- withdraw → stream.recipient.require_auth()
- cancel_stream → sender.require_auth() OR recipient.require_auth()

claim_stream uses secret-hash verification instead (SHA-256 comparison).

## Events

Every state change emits a Soroban event:
- (CREATED, stream_id) → (sender, recipient, token, deposit, claim_hash)
- (CLAIMED, stream_id) → recipient
- (WITHDRAWN, stream_id) → (recipient, amount)
- (CANCELD, stream_id) → (sender, recipient, sender_balance, recipient_balance)

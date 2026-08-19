# 📜 Soroban Smart Contract Documentation

Contract ID: `CCCFBMNEBOV7KTVWLEBR2FFUGQC4KSL5TSITVU5ZPQ2U3PNLQJGX62W2`  
Network: **Stellar Testnet**

This document provides a technical reference for the **inFlow Soroban Smart Contract** written in Rust.

---

## 🏗️ Data Structures

### `Stream`
```rust
pub struct Stream {
    pub id: u64,
    pub sender: Address,
    pub recipient: Address,
    pub token: Address,
    pub deposit: i128,
    pub rate_per_second: i128,
    pub start_time: u64,
    pub stop_time: u64,
    pub withdrawn_amount: i128,
    pub remaining_balance: i128,
    pub active: bool,
}
```

---

## ⚡ Public Contract Functions

### 1. `create_stream`
Creates a new real-time salary stream and locks the specified USDC deposit in the contract vault.

```rust
pub fn create_stream(
    env: Env,
    sender: Address,
    recipient: Address,
    token: Address,
    deposit: i128,
    duration_seconds: u64,
) -> u64
```
- **`sender`**: Address of employer depositing funds. Must authenticate transaction.
- **`recipient`**: Address of employee receiving real-time wage stream.
- **`token`**: Address of Soroban Asset Contract (e.g. Circle USDC SAC).
- **`deposit`**: Total amount of tokens to lock.
- **`duration_seconds`**: Streaming duration in seconds (e.g., 2,592,000 for 30 days).
- **Returns**: `u64` representing the unique `stream_id`.

---

### 2. `withdraw_from_stream`
Allows the recipient to collect unlocked accumulated earnings on demand.

```rust
pub fn withdraw_from_stream(
    env: Env,
    recipient: Address,
    stream_id: u64,
    amount: i128,
) -> i128
```
- **`recipient`**: Address of employee collecting earnings. Must authenticate.
- **`stream_id`**: ID of the target stream.
- **`amount`**: Desired withdrawal amount (must be `<= unlocked_amount - withdrawn_amount`).
- **Returns**: `i128` actual transferred token amount.

---

### 3. `cancel_stream`
Allows the employer to cancel an active stream. Unearned funds revert to the employer; earned funds remain unlocked for the employee.

```rust
pub fn cancel_stream(
    env: Env,
    sender: Address,
    stream_id: u64,
) -> bool
```
- **`sender`**: Address of stream creator (employer). Must authenticate.
- **`stream_id`**: ID of stream to cancel.
- **Returns**: `bool` indicating cancellation success.

---

### 4. `get_stream`
Returns current stream state, total deposit, rate per second, and unlocked amount.

```rust
pub fn get_stream(env: Env, stream_id: u64) -> Stream
```

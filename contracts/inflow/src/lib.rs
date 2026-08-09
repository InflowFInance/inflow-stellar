#![no_std]

pub mod error;
pub mod events;
pub mod math;
pub mod storage;
pub mod types;

use crate::error::ContractError;
use crate::events::*;
use crate::math::*;
use crate::storage::*;
use crate::types::*;
use soroban_sdk::{contract, contractimpl, Address, Bytes, BytesN, Env, panic_with_error};

#[contract]
pub struct Inflow;

#[contractimpl]
impl Inflow {
    pub fn create_stream(
        env: Env,
        sender: Address,
        recipient: Address,
        token: Address,
        params: StreamParams,
    ) -> u32 {
        sender.require_auth();

        if params.deposit <= 0 {
            panic_with_error!(&env, ContractError::ZeroDeposit);
        }
        if params.top_up < 0 {
            panic_with_error!(&env, ContractError::ZeroAmount);
        }
        if params.end_time <= params.start_time {
            panic_with_error!(&env, ContractError::InvalidDuration);
        }

        let id = get_next_stream_id(&env);
        let stop_time = params.end_time;

        let stream = Stream {
            sender: sender.clone(),
            recipient: recipient.clone(),
            token: token.clone(),
            params: params.clone(),
            claimed: 0,
            stop_time,
            recipient_has_claimed: false,
            status: StreamStatus::Active,
        };

        put_stream(&env, id, &stream);
        set_next_stream_id(&env, id);

        emit_stream_created(&env, id, &sender, &recipient, &token, params.deposit, None);

        id
    }

    pub fn claim_stream(env: Env, stream_id: u32, secret: Bytes) {
        let mut stream = match get_stream(&env, stream_id) {
            Some(s) => s,
            None => panic_with_error!(&env, ContractError::StreamNotFound),
        };

        if stream.recipient_has_claimed {
            panic_with_error!(&env, ContractError::StreamAlreadyClaimed);
        }

        let claim_hash = stream.params.claim_hash.clone();
        if claim_hash == BytesN::<32>::from_array(&env, &[0u8; 32]) {
            panic_with_error!(&env, ContractError::InvalidClaimHash);
        }

        let secret_hash = env.crypto().sha256(&secret);
        if secret_hash.to_bytes() != claim_hash {
            panic_with_error!(&env, ContractError::InvalidClaimHash);
        }

        stream.recipient_has_claimed = true;
        stream.params.claim_hash = BytesN::<32>::from_array(&env, &[0u8; 32]);
        put_stream(&env, stream_id, &stream);

        emit_stream_claimed(&env, stream_id);
    }

    pub fn withdraw(env: Env, stream_id: u32, amount: i128) -> WithdrawResult {
        let now = env.ledger().timestamp();
        let mut stream = match get_stream(&env, stream_id) {
            Some(s) => s,
            None => panic_with_error!(&env, ContractError::StreamNotFound),
        };

        if stream.status == StreamStatus::Canceled {
            panic_with_error!(&env, ContractError::NotAuthorized);
        }

        stream.recipient.require_auth();

        let total_deposit = stream.params.deposit + stream.params.top_up;
        let unlocked = compute_amount_unlocked(
            total_deposit,
            stream.params.start_time,
            stream.params.end_time,
            now,
        );
        let available = unlocked - stream.claimed;

        if available <= 0 {
            panic_with_error!(&env, ContractError::InsufficientBalance);
        }

        let amount_to_withdraw = if amount <= 0 { available } else { amount.min(available) };

        stream.claimed += amount_to_withdraw;
        put_stream(&env, stream_id, &stream);

        let mut balance = get_balance(&env, &stream.recipient);
        balance += amount_to_withdraw;
        put_balance(&env, &stream.recipient, balance);

        emit_stream_withdrawn(&env, stream_id, amount_to_withdraw);

        WithdrawResult {
            amount: amount_to_withdraw,
            stream_id,
        }
    }

    pub fn cancel_stream(env: Env, stream_id: u32) -> CancelResult {
        let mut stream = match get_stream(&env, stream_id) {
            Some(s) => s,
            None => panic_with_error!(&env, ContractError::StreamNotFound),
        };

        stream.sender.require_auth();
        stream.recipient.require_auth();

        stream.status = StreamStatus::Canceled;
        put_stream(&env, stream_id, &stream);

        emit_stream_canceled(&env, stream_id);

        CancelResult {
            sender_amount: 0,
            recipient_amount: 0,
            stream_id,
        }
    }
}

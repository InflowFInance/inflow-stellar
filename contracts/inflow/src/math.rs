use crate::types::Stream;
use soroban_sdk::Env;

pub fn unlocked_balance(env: &Env, stream: &Stream) -> i128 {
    if stream.recipient.is_none() {
        return 0;
    }

    let now = env.ledger().timestamp();

    if now <= stream.start_time {
        return 0;
    }

    if now >= stream.stop_time {
        return stream.deposit;
    }

    let elapsed = (now - stream.start_time) as i128;
    elapsed * stream.rate_per_second
}

pub fn available_to_withdraw(env: &Env, stream: &Stream) -> i128 {
    unlocked_balance(env, stream) - stream.withdrawn_amount
}

pub fn cancellation_split(env: &Env, stream: &Stream) -> (i128, i128) {
    let recipient_gets = available_to_withdraw(env, stream);
    let sender_gets = stream.remaining_balance - recipient_gets;
    (sender_gets, recipient_gets)
}

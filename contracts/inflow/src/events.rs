use soroban_sdk::{symbol_short, Address, BytesN, Env, Option as SorobanOption};

pub fn emit_stream_created(
    env: &Env,
    stream_id: u64,
    sender: &Address,
    recipient: &SorobanOption<Address>,
    token: &Address,
    deposit: i128,
    claim_hash: &SorobanOption<BytesN<32>>,
) {
    env.events().publish(
        (symbol_short!("CREATED"), stream_id),
        (sender.clone(), recipient.clone(), token.clone(), deposit, claim_hash.clone()),
    );
}

pub fn emit_stream_claimed(env: &Env, stream_id: u64, recipient: &Address) {
    env.events().publish(
        (symbol_short!("CLAIMED"), stream_id),
        recipient.clone(),
    );
}

pub fn emit_withdrawn(env: &Env, stream_id: u64, recipient: &Address, amount: i128) {
    env.events().publish(
        (symbol_short!("WITHDREW"), stream_id),
        (recipient.clone(), amount),
    );
}

pub fn emit_cancelled(
    env: &Env,
    stream_id: u64,
    sender: &Address,
    recipient: &SorobanOption<Address>,
    sender_balance: i128,
    recipient_balance: i128,
) {
    env.events().publish(
        (symbol_short!("CANCELD"), stream_id),
        (sender.clone(), recipient.clone(), sender_balance, recipient_balance),
    );
}

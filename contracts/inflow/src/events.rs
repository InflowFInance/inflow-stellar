use soroban_sdk::{Address, Bytes, Env};

pub fn emit_stream_created(
    _env: &Env,
    _stream_id: u32,
    _sender: &Address,
    _recipient: &Address,
    _token: &Address,
    _deposit: i128,
    _claim_hash: Option<Bytes>,
) {
}

pub fn emit_stream_claimed(_env: &Env, _stream_id: u32) {}

pub fn emit_stream_withdrawn(_env: &Env, _stream_id: u32, _amount: i128) {}

pub fn emit_stream_canceled(_env: &Env, _stream_id: u32) {}

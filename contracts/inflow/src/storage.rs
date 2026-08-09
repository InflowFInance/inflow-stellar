use soroban_sdk::{Address, Env};
use crate::types::{Stream, StorageKey};
use crate::errors::ContractError;

pub const TTL_THRESHOLD: u32 = 10_000;
pub const TTL_EXTEND_TO: u32 = 6_307_200;

pub fn read_stream(env: &Env, stream_id: u64) -> Result<Stream, ContractError> {
    let key = StorageKey::Stream(stream_id);
    let stream = env
        .storage()
        .persistent()
        .get::<StorageKey, Stream>(&key)
        .ok_or(ContractError::StreamNotFound)?;

    // Touch-on-read: extend TTL on every read
    extend_stream_ttl_internal(env, stream_id);

    Ok(stream)
}

pub fn write_stream(env: &Env, stream_id: u64, stream: &Stream) {
    let key = StorageKey::Stream(stream_id);
    env.storage().persistent().set(&key, stream);
    extend_stream_ttl_internal(env, stream_id);
}

pub fn read_next_stream_id(env: &Env) -> u64 {
    env.storage()
        .instance()
        .get::<StorageKey, u64>(&StorageKey::NextStreamId)
        .unwrap_or(1)
}

pub fn write_next_stream_id(env: &Env, id: u64) {
    env.storage().instance().set(&StorageKey::NextStreamId, &id);
    env.storage().instance().extend_ttl(TTL_THRESHOLD, TTL_EXTEND_TO);
}

pub fn extend_stream_ttl_internal(env: &Env, stream_id: u64) {
    let key = StorageKey::Stream(stream_id);
    env.storage().persistent().extend_ttl(&key, TTL_THRESHOLD, TTL_EXTEND_TO);
}

pub fn read_admin(env: &Env) -> Option<Address> {
    env.storage().instance().get::<StorageKey, Address>(&StorageKey::Admin)
}

pub fn write_admin(env: &Env, admin: &Address) {
    env.storage().instance().set(&StorageKey::Admin, admin);
    env.storage().instance().extend_ttl(TTL_THRESHOLD, TTL_EXTEND_TO);
}

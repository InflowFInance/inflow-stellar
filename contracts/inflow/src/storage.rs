use crate::types::*;
use soroban_sdk::{contracttype, Address, Env, Symbol};

#[contracttype]
pub struct StreamKey {
    pub id: u32,
}

pub fn has_stream(env: &Env, id: u32) -> bool {
    let key = StreamKey { id };
    env.storage().persistent().has(&key)
}

pub fn get_stream(env: &Env, id: u32) -> Option<Stream> {
    let key = StreamKey { id };
    env.storage().persistent().get(&key)
}

pub fn put_stream(env: &Env, id: u32, stream: &Stream) {
    let key = StreamKey { id };
    env.storage().persistent().set(&key, stream);
}

pub fn del_stream(env: &Env, id: u32) {
    let key = StreamKey { id };
    env.storage().persistent().remove(&key);
}

pub fn get_balance(env: &Env, address: &Address) -> i128 {
    let key = (Symbol::new(env, "BAL"), address);
    env.storage().persistent().get(&key).unwrap_or(0)
}

pub fn put_balance(env: &Env, address: &Address, amount: i128) {
    let key = (Symbol::new(env, "BAL"), address);
    env.storage().persistent().set(&key, &amount);
}

pub fn get_next_stream_id(env: &Env) -> u32 {
    let key = Symbol::new(env, "ADMIN");
    let id: u32 = env.storage().temporary().get(&key).unwrap_or(0);
    id + 1
}

pub fn set_next_stream_id(env: &Env, id: u32) {
    let key = Symbol::new(env, "ADMIN");
    env.storage().temporary().set(&key, &id);
}

pub fn get_config(env: &Env) -> Option<Config> {
    let key = Symbol::new(env, "CONFIG");
    env.storage().persistent().get(&key)
}

pub fn put_config(env: &Env, config: &Config) {
    let key = Symbol::new(env, "CONFIG");
    env.storage().persistent().set(&key, config);
}

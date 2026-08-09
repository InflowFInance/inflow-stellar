use soroban_sdk::{contracttype, Address, BytesN};

#[contracttype]
#[derive(Clone, Debug, PartialEq)]
pub struct Stream {
    pub sender: Address,
    pub recipient: Option<Address>,
    pub token: Address,
    pub deposit: i128,
    pub rate_per_second: i128,
    pub start_time: u64,
    pub stop_time: u64,
    pub withdrawn_amount: i128,
    pub remaining_balance: i128,
    pub claim_hash: Option<BytesN<32>>,
}

#[contracttype]
#[derive(Clone, Debug, PartialEq)]
pub enum StorageKey {
    Stream(u64),
    NextStreamId,
    Admin,
}

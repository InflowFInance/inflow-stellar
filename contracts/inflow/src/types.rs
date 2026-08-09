use soroban_sdk::{contracttype, Address, BytesN};

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct StreamParams {
    pub deposit: i128,
    pub start_time: u64,
    pub end_time: u64,
    pub top_up: i128,
    pub claim_hash: BytesN<32>,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Stream {
    pub sender: Address,
    pub recipient: Address,
    pub token: Address,
    pub params: StreamParams,
    pub claimed: i128,
    pub stop_time: u64,
    pub recipient_has_claimed: bool,
    pub status: StreamStatus,
}

#[contracttype]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum StreamStatus {
    Active = 0,
    Canceled = 1,
    Completed = 2,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct WithdrawResult {
    pub amount: i128,
    pub stream_id: u32,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CancelResult {
    pub sender_amount: i128,
    pub recipient_amount: i128,
    pub stream_id: u32,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Config {
    pub fee_bump: bool,
    pub fee_bump_public_key: Address,
    pub admin: Address,
    pub next_stream_id: u32,
}

use soroban_sdk::contracterror;

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
pub enum ContractError {
    // Stream lifecycle
    StreamAlreadyExists = 0,
    StreamNotFound = 1,
    StreamExpired = 2,
    StreamNotExpired = 3,
    StreamNotClaimed = 4,
    StreamAlreadyClaimed = 5,
    StreamRecipientMismatch = 6,
    StreamNotPaused = 7,
    StreamPaused = 8,
    // Balance / amount
    ZeroAmount = 9,
    ZeroDeposit = 10,
    InsufficientBalance = 11,
    // Authorization
    NotAuthorized = 12,
    // Timestamps
    StartTimeInPast = 13,
    StartTimeNotReached = 14,
    InvalidDuration = 15,
    // Claim flow
    InvalidClaimHash = 16,
    // Storage
    StorageFull = 17,
    // Token
    InvalidToken = 18,
    TransferFailed = 19,
    // General
    GenericError = 20,
}

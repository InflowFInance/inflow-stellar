use soroban_sdk::contracterror;

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
#[repr(u32)]
pub enum ContractError {
    StreamNotFound = 1,
    StreamAlreadyClaimed = 2,
    InvalidClaimSecret = 3,
    NotClaimableStream = 4,
    InsufficientBalance = 5,
    Unauthorized = 6,
    InvalidTimeRange = 7,
    InvalidDeposit = 8,
    StreamDepleted = 9,
    RecipientNotSet = 10,
    StreamToSelf = 11,
    MustProvideRecipientOrHash = 12,
    CannotProvideBoth = 13,
}

#![no_std]

mod errors;
mod events;
mod math;
mod storage;
mod types;

use soroban_sdk::{
    contract, contractimpl, token, Address, Bytes, BytesN, Env,
    Option as SorobanOption,
};

pub use errors::ContractError;
pub use math::{available_to_withdraw, cancellation_split, unlocked_balance};
pub use storage::{
    extend_stream_ttl_internal, read_next_stream_id, read_stream,
    write_admin, write_next_stream_id, write_stream,
};
pub use types::{StorageKey, Stream};

fn compute_hash(env: &Env, data: &Bytes) -> BytesN<32> {
    env.crypto().sha256(data)
}

#[contract]
pub struct InFlowContract;

#[contractimpl]
impl InFlowContract {
    pub fn initialize(env: Env, admin: Address) {
        admin.require_auth();
        write_admin(&env, &admin);
        write_next_stream_id(&env, 1);
    }

    pub fn create_stream(
        env: Env,
        sender: Address,
        recipient: SorobanOption<Address>,
        token: Address,
        deposit: i128,
        start_time: u64,
        stop_time: u64,
        claim_hash: SorobanOption<BytesN<32>>,
    ) -> Result<u64, ContractError> {
        sender.require_auth();

        match (&recipient, &claim_hash) {
            (SorobanOption::Some(_), SorobanOption::Some(_)) => {
                return Err(ContractError::CannotProvideBoth)
            }
            (SorobanOption::None, SorobanOption::None) => {
                return Err(ContractError::MustProvideRecipientOrHash)
            }
            _ => {}
        }

        if let SorobanOption::Some(ref r) = recipient {
            if *r == sender {
                return Err(ContractError::StreamToSelf);
            }
        }

        if deposit <= 0 {
            return Err(ContractError::InvalidDeposit);
        }

        let now = env.ledger().timestamp();
        if start_time < now {
            return Err(ContractError::InvalidTimeRange);
        }
        if stop_time <= start_time {
            return Err(ContractError::InvalidTimeRange);
        }

        let duration = (stop_time - start_time) as i128;
        if deposit % duration != 0 {
            return Err(ContractError::InvalidDeposit);
        }
        let rate_per_second = deposit / duration;

        let token_client = token::Client::new(&env, &token);
        token_client.transfer_from(
            &env.current_contract_address(),
            &sender,
            &env.current_contract_address(),
            &deposit,
        );

        let stream_id = read_next_stream_id(&env);
        let stream = Stream {
            sender: sender.clone(),
            recipient: recipient.clone(),
            token: token.clone(),
            deposit,
            rate_per_second,
            start_time,
            stop_time,
            withdrawn_amount: 0,
            remaining_balance: deposit,
            claim_hash: claim_hash.clone(),
        };

        write_stream(&env, stream_id, &stream);
        write_next_stream_id(&env, stream_id + 1);

        events::emit_stream_created(
            &env,
            stream_id,
            &sender,
            &recipient,
            &token,
            deposit,
            &claim_hash,
        );

        Ok(stream_id)
    }

    pub fn claim_stream(env: Env, stream_id: u64, secret: Bytes) -> Result<(), ContractError> {
        let mut stream = read_stream(&env, stream_id)?;

        if stream.claim_hash.is_none() {
            return Err(ContractError::NotClaimableStream);
        }
        if stream.recipient.is_some() {
            return Err(ContractError::StreamAlreadyClaimed);
        }

        let provided_hash = compute_hash(&env, &secret);
        let expected_hash = stream.claim_hash.clone().unwrap();

        if provided_hash != expected_hash {
            return Err(ContractError::InvalidClaimSecret);
        }

        let claimer = env.invoker();
        stream.recipient = SorobanOption::Some(claimer.clone());
        stream.claim_hash = SorobanOption::None;

        write_stream(&env, stream_id, &stream);
        events::emit_stream_claimed(&env, stream_id, &claimer);

        Ok(())
    }

    pub fn withdraw(env: Env, stream_id: u64, amount: i128) -> Result<(), ContractError> {
        let mut stream = read_stream(&env, stream_id)?;
        let recipient = stream
            .recipient
            .clone()
            .ok_or(ContractError::RecipientNotSet)?;

        recipient.require_auth();

        if amount <= 0 {
            return Err(ContractError::InvalidDeposit);
        }

        let available = available_to_withdraw(&env, &stream);
        if amount > available {
            return Err(ContractError::InsufficientBalance);
        }

        stream.withdrawn_amount += amount;
        stream.remaining_balance -= amount;
        write_stream(&env, stream_id, &stream);

        let token_client = token::Client::new(&env, &stream.token);
        token_client.transfer(&env.current_contract_address(), &recipient, &amount);

        events::emit_withdrawn(&env, stream_id, &recipient, amount);

        Ok(())
    }

    pub fn cancel_stream(env: Env, stream_id: u64) -> Result<(), ContractError> {
        let mut stream = read_stream(&env, stream_id)?;
        let invoker = env.invoker();

        let is_sender = invoker == stream.sender;
        let is_recipient = stream
            .recipient
            .as_ref()
            .map(|r| *r == invoker)
            .unwrap_or(false);

        if !is_sender && !is_recipient {
            return Err(ContractError::Unauthorized);
        }

        if stream.remaining_balance == 0 {
            return Err(ContractError::StreamDepleted);
        }

        let (sender_gets, recipient_gets) = cancellation_split(&env, &stream);
        stream.remaining_balance = 0;
        write_stream(&env, stream_id, &stream);

        let token_client = token::Client::new(&env, &stream.token);

        if recipient_gets > 0 {
            if let SorobanOption::Some(ref recipient) = stream.recipient {
                token_client.transfer(
                    &env.current_contract_address(),
                    recipient,
                    &recipient_gets,
                );
            }
        }

        if sender_gets > 0 {
            token_client.transfer(
                &env.current_contract_address(),
                &stream.sender,
                &sender_gets,
            );
        }

        events::emit_cancelled(
            &env,
            stream_id,
            &stream.sender,
            &stream.recipient,
            sender_gets,
            recipient_gets,
        );

        Ok(())
    }

    pub fn extend_stream_ttl(env: Env, stream_id: u64) -> Result<(), ContractError> {
        read_stream(&env, stream_id)?;
        extend_stream_ttl_internal(&env, stream_id);
        Ok(())
    }

    pub fn get_stream(env: Env, stream_id: u64) -> Result<Stream, ContractError> {
        read_stream(&env, stream_id)
    }

    pub fn get_next_stream_id(env: Env) -> u64 {
        read_next_stream_id(&env)
    }

    pub fn unlocked_balance(env: Env, stream_id: u64) -> Result<i128, ContractError> {
        let stream = read_stream(&env, stream_id)?;
        Ok(math::unlocked_balance(&env, &stream))
    }

    pub fn available_to_withdraw(env: Env, stream_id: u64) -> Result<i128, ContractError> {
        let stream = read_stream(&env, stream_id)?;
        Ok(math::available_to_withdraw(&env, &stream))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use soroban_sdk::{
        testutils::{Address as _, Ledger},
        token, Bytes, Env,
    };

    fn create_test_env() -> (Env, InFlowContractClient<'static>, Address, Address) {
        let env = Env::default();
        env.mock_all_auths();

        let contract_id = env.register_contract(None, InFlowContract);
        let client = InFlowContractClient::new(&env, &contract_id);
        let admin = Address::generate(&env);

        client.initialize(&admin);
        (env, client, contract_id, admin)
    }

    fn create_token<'a>(
        env: &'a Env,
        admin: &Address,
    ) -> (Address, token::StellarAssetClient<'a>) {
        let token_id = env.register_stellar_asset_contract(admin.clone());
        let client = token::StellarAssetClient::new(env, &token_id);
        (token_id, client)
    }

    #[test]
    fn test_initialize_and_create_stream() {
        let (env, client, _, _) = create_test_env();
        let sender = Address::generate(&env);
        let recipient = Address::generate(&env);
        let (token_id, token_admin) = create_token(&env, &sender);

        token_admin.mint(&sender, &1_000_000_000_000i128);

        let now = env.ledger().timestamp();
        let start = now + 60;
        let duration = 2_592_000u64;
        let stop = start + duration;
        let deposit = (duration as i128) * 100;

        let stream_id = client
            .create_stream(
                &sender,
                &SorobanOption::Some(recipient.clone()),
                &token_id,
                &deposit,
                &start,
                &stop,
                &SorobanOption::None,
            )
            .unwrap();

        assert_eq!(stream_id, 1);
        let stream = client.get_stream(&stream_id).unwrap();
        assert_eq!(stream.sender, sender);
        assert_eq!(stream.deposit, deposit);
        assert_eq!(stream.remaining_balance, deposit);
        assert_eq!(stream.withdrawn_amount, 0);
    }

    #[test]
    fn test_claim_stream_secret_verification() {
        let (env, client, _, _) = create_test_env();
        let sender = Address::generate(&env);
        let claimer = Address::generate(&env);
        let (token_id, token_admin) = create_token(&env, &sender);

        token_admin.mint(&sender, &1_000_000_000_000i128);

        let secret = Bytes::from_slice(&env, b"my-secret-claim-passphrase");
        let claim_hash = env.crypto().sha256(&secret);

        let now = env.ledger().timestamp();
        let start = now + 60;
        let duration = 3600u64;
        let stop = start + duration;
        let deposit = (duration as i128) * 10;

        let stream_id = client
            .create_stream(
                &sender,
                &SorobanOption::None,
                &token_id,
                &deposit,
                &start,
                &stop,
                &SorobanOption::Some(claim_hash),
            )
            .unwrap();

        // Wrong secret fails
        let wrong_secret = Bytes::from_slice(&env, b"wrong-secret");
        let err = client.try_claim_stream(&stream_id, &wrong_secret);
        assert!(err.is_err());

        // Correct secret succeeds
        client.claim_stream(&stream_id, &secret).unwrap();

        let stream = client.get_stream(&stream_id).unwrap();
        assert!(stream.recipient.is_some());
    }
}

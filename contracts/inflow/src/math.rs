pub fn compute_amount_unlocked(
    total_deposit: i128,
    start_time: u64,
    end_time: u64,
    current_time: u64,
) -> i128 {
    if current_time >= end_time {
        return total_deposit;
    }
    if current_time <= start_time {
        return 0;
    }
    let duration = (end_time - start_time) as i128;
    let elapsed = (current_time - start_time) as i128;
    (total_deposit * elapsed) / duration
}

pub fn compute_balances(
    deposit: i128,
    top_up: i128,
    start_time: u64,
    end_time: u64,
    cancel_time: u64,
    claimed: i128,
) -> (i128, i128) {
    let total_deposit = deposit + top_up;
    let unlocked = compute_amount_unlocked(total_deposit, start_time, end_time, cancel_time);
    let sender_balance = total_deposit - unlocked - claimed;
    let recipient_balance = unlocked - claimed;
    (sender_balance, recipient_balance)
}

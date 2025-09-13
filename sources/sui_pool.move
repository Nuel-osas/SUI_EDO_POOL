module pool::sui_pool {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    const EInsufficientBalance: u64 = 1;
    const EInvalidAmount: u64 = 2;

    struct Pool has key {
        id: UID,
        balance: Balance<SUI>,
        total_deposits: u64,
    }

    struct DepositEvent has copy, drop {
        pool_id: address,
        user: address,
        amount: u64,
        timestamp: u64,
    }

    struct WithdrawEvent has copy, drop {
        pool_id: address,
        user: address,
        amount: u64,
        timestamp: u64,
    }

    fun init(ctx: &mut TxContext) {
        let pool = Pool {
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            total_deposits: 0,
        };
        transfer::share_object(pool);
    }

    /// Deposit a specific amount of SUI into the pool
    public entry fun deposit_amount(
        pool: &mut Pool,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(amount > 0, EInvalidAmount);
        assert!(coin::value(payment) >= amount, EInsufficientBalance);

        // Split the exact amount from the payment coin
        let deposit_coin = coin::split(payment, amount, ctx);
        let coin_balance = coin::into_balance(deposit_coin);

        balance::join(&mut pool.balance, coin_balance);
        pool.total_deposits = pool.total_deposits + amount;

        event::emit(DepositEvent {
            pool_id: object::uid_to_address(&pool.id),
            user: tx_context::sender(ctx),
            amount,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });
    }

    /// Withdraw a specific amount of SUI from the pool
    public entry fun withdraw_amount(
        pool: &mut Pool,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(amount > 0, EInvalidAmount);
        assert!(balance::value(&pool.balance) >= amount, EInsufficientBalance);

        let withdraw_balance = balance::split(&mut pool.balance, amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        pool.total_deposits = pool.total_deposits - amount;

        event::emit(WithdrawEvent {
            pool_id: object::uid_to_address(&pool.id),
            user: tx_context::sender(ctx),
            amount,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::public_transfer(withdraw_coin, tx_context::sender(ctx));
    }

    /// Withdraw all SUI from the pool
    public entry fun withdraw_all(
        pool: &mut Pool,
        ctx: &mut TxContext
    ) {
        let amount = balance::value(&pool.balance);
        assert!(amount > 0, EInvalidAmount);

        let withdraw_balance = balance::withdraw_all(&mut pool.balance);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        pool.total_deposits = 0;

        event::emit(WithdrawEvent {
            pool_id: object::uid_to_address(&pool.id),
            user: tx_context::sender(ctx),
            amount,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::public_transfer(withdraw_coin, tx_context::sender(ctx));
    }

    /// Get the current balance of the pool
    public fun get_pool_balance(pool: &Pool): u64 {
        balance::value(&pool.balance)
    }

    /// Get the total deposits made to the pool
    public fun get_total_deposits(pool: &Pool): u64 {
        pool.total_deposits
    }
}
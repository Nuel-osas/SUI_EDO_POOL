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

    struct UserDeposit has key, store {
        id: UID,
        owner: address,
        amount: u64,
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

    public fun deposit(
        pool: &mut Pool,
        coin: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&coin);
        assert!(amount > 0, EInvalidAmount);

        let coin_balance = coin::into_balance(coin);
        balance::join(&mut pool.balance, coin_balance);
        pool.total_deposits = pool.total_deposits + amount;

        let user_deposit = UserDeposit {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            amount,
        };

        event::emit(DepositEvent {
            pool_id: object::uid_to_address(&pool.id),
            user: tx_context::sender(ctx),
            amount,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::transfer(user_deposit, tx_context::sender(ctx));
    }

    public fun withdraw(
        pool: &mut Pool,
        user_deposit: UserDeposit,
        ctx: &mut TxContext
    ) {
        let UserDeposit { id, owner, amount } = user_deposit;
        assert!(owner == tx_context::sender(ctx), EInsufficientBalance);
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

        object::delete(id);
        transfer::public_transfer(withdraw_coin, tx_context::sender(ctx));
    }

    public fun withdraw_partial(
        pool: &mut Pool,
        user_deposit: &mut UserDeposit,
        withdraw_amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(user_deposit.owner == tx_context::sender(ctx), EInsufficientBalance);
        assert!(user_deposit.amount >= withdraw_amount, EInsufficientBalance);
        assert!(balance::value(&pool.balance) >= withdraw_amount, EInsufficientBalance);
        assert!(withdraw_amount > 0, EInvalidAmount);

        user_deposit.amount = user_deposit.amount - withdraw_amount;

        let withdraw_balance = balance::split(&mut pool.balance, withdraw_amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        pool.total_deposits = pool.total_deposits - withdraw_amount;

        event::emit(WithdrawEvent {
            pool_id: object::uid_to_address(&pool.id),
            user: tx_context::sender(ctx),
            amount: withdraw_amount,
            timestamp: tx_context::epoch_timestamp_ms(ctx),
        });

        transfer::public_transfer(withdraw_coin, tx_context::sender(ctx));
    }

    public fun get_pool_balance(pool: &Pool): u64 {
        balance::value(&pool.balance)
    }

    public fun get_total_deposits(pool: &Pool): u64 {
        pool.total_deposits
    }

    public fun get_user_deposit_amount(user_deposit: &UserDeposit): u64 {
        user_deposit.amount
    }
}
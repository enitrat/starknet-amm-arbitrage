%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.math import unsigned_div_rem, assert_nn, assert_not_zero
from starkware.cairo.common.math_cmp import is_nn, is_not_zero
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import TRUE, FALSE

struct Pair:
    member reserve_1 : felt
    member reserve_2 : felt
end

@storage_var
func _pair(token_a : felt, token_b : felt) -> (pair : Pair):
end

@storage_var
func _user_balance(address : felt, token : felt) -> (balance : felt):
end

@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_a : felt, token_b : felt
) -> (reserve_1 : felt, reserve_2 : felt, inversed : felt):
    alloc_locals
    let (storage_pair) = _pair.read(token_a, token_b)
    let (pair_exists) = is_not_zero(storage_pair.reserve_1)  # Pair is not initialized if reserve_1 is zero
    let (inversed_pair) = _pair.read(token_b, token_a)
    local inversed : felt
    if pair_exists == FALSE:
        tempvar temp_pair = inversed_pair
        inversed = TRUE
    else:
        tempvar temp_pair = storage_pair
        inversed = FALSE
    end
    local pair : Pair = temp_pair
    assert_not_zero(pair.reserve_1)
    return (pair.reserve_1, pair.reserve_2, inversed)
end

@external
func set_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_a : felt, token_b : felt, reserve_1 : felt, reserve_2 : felt
):
    _pair.write(token_a, token_b, Pair(reserve_1, reserve_2))
    return ()
end

@external
func set_user_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, amount : felt
):
    let (caller_address) = get_caller_address()
    _user_balance.write(caller_address, token, amount)
    return ()
end

@view
func get_user_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (balance : felt):
    let (caller_address) = get_caller_address()
    let (balance) = _user_balance.read(caller_address, token)
    return (balance)
end

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_from : felt, token_to : felt, amount : felt
) -> (res : felt):
    alloc_locals
    let (reserve_1, reserve_2, inversed) = get_reserves(token_from, token_to)
    local reserveFrom : felt
    local reserveTo : felt
    if inversed == FALSE:
        reserveFrom = reserve_1
        reserveTo = reserve_2
    else:
        reserveFrom = reserve_2
        reserveTo = reserve_1
    end
    let (local amount_to, _) = unsigned_div_rem(reserveTo * amount, reserveFrom + amount)
    let (caller_address) = get_caller_address()

    let (prev_balance_to) = get_user_balance(token_to)
    let (prev_balance_from) = get_user_balance(token_from)

    let new_balance_to = prev_balance_to + amount_to
    let new_balance_from = prev_balance_from - amount

    set_user_balance(token_to, new_balance_to)
    set_user_balance(token_from, new_balance_from)

    set_reserves(token_from, token_to, reserveFrom + amount, reserveTo - amount_to)
    return (amount_to)
end

@view
func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount_out : felt, reserve_in : felt, reserve_out : felt
) -> (res : felt):
    assert_nn(amount_out)
    assert_not_zero(amount_out)

    assert_nn(reserve_in)
    assert_not_zero(reserve_in)

    assert_nn(reserve_out)
    assert_not_zero(reserve_out)

    let numerator = reserve_in * amount_out
    let denominator = reserve_out - amount_out
    let (amount_in, _) = unsigned_div_rem(numerator, denominator)
    return (amount_in)
end

@view
func get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount_in : felt, reserve_in : felt, reserve_out : felt
) -> (res : felt):
    assert_nn(amount_in)
    assert_not_zero(amount_in)

    assert_nn(reserve_in)
    assert_not_zero(reserve_in)

    assert_nn(reserve_out)
    assert_not_zero(reserve_out)

    let numerator = reserve_out * amount_in
    let denominator = reserve_out + amount_in
    let (amount_out, _) = unsigned_div_rem(numerator, denominator)
    return (amount_out)
end

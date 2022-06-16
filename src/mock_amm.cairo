%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.math import unsigned_div_rem, assert_nn, assert_not_zero
from starkware.cairo.common.math_cmp import is_nn, is_not_zero, is_le
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import TRUE, FALSE
from lib.DataTypes import Pair

@storage_var
func _pair(token0 : felt, token1 : felt) -> (pair : Pair):
end

@storage_var
func _user_balance(address : felt, token : felt) -> (balance : felt):
end

@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token0 : felt, token1 : felt
) -> (reserve0 : felt, reserve1 : felt, inversed : felt):
    alloc_locals
    let (storage_pair) = _pair.read(token0, token1)
    let (pair_exists) = is_not_zero(storage_pair.reserve0)  # Pair is not initialized if reserve0 is zero
    let (inversed_pair) = _pair.read(token1, token0)
    local inversed : felt
    if pair_exists == FALSE:
        tempvar temp_pair = inversed_pair
        inversed = TRUE
    else:
        tempvar temp_pair = storage_pair
        inversed = FALSE
    end
    local pair : Pair = temp_pair
    assert_not_zero(pair.reserve0)
    return (pair.reserve0, pair.reserve1, inversed)
end

##
# Sets the reserve of a pair
# @dev token0 is ALWAYS lower than token1
##
@external
func set_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token0 : felt, token1 : felt, reserve0 : felt, reserve1 : felt
):
    alloc_locals
    let (is_0_lower_1) = is_le(token0, token1)
    local _token0 : felt
    local _token1 : felt
    local _reserve0 : felt
    local _reserve1 : felt
    if is_0_lower_1 == FALSE:
        _token0 = token1
        _token1 = token0
        _reserve0 = reserve1
        _reserve1 = reserve0
    else:
        _token0 = token0
        _token1 = token1
        _reserve0 = reserve0
        _reserve1 = reserve1
    end

    _pair.write(_token0, _token1, Pair(_token0, _token1, _reserve0, _reserve1))
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
    let (reserve0, reserve1, inversed) = get_reserves(token_from, token_to)
    local reserveFrom : felt
    local reserveTo : felt
    if inversed == FALSE:
        reserveFrom = reserve0
        reserveTo = reserve1
    else:
        reserveFrom = reserve1
        reserveTo = reserve0
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

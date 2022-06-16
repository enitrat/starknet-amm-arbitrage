%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (
    assert_nn,
    sqrt,
    assert_not_zero,
    unsigned_div_rem,
    assert_le,
)
from starkware.cairo.common.math_cmp import is_not_zero, is_nn, is_le
from starkware.cairo.common.bool import TRUE, FALSE
from lib.DataTypes import Pair, OrderedReserves

# func get_profit{range_check_ptr}(pair1 : Pair, pair2 : Pair) -> (profit : felt):
# end

##
# Our contract will have arbitrage enabled only for specific tokens
##
@storage_var
func arbitrage_tokens(token : felt) -> (activated : felt):
end

@external
func add_base_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
):
    arbitrage_tokens.write(token, TRUE)
    return ()
end

@external
func remove_base_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
):
    arbitrage_tokens.write(token, FALSE)
    return ()
end

##
# Given two pairs, verifies that both are valid pairs, and that they contain a base token that we want to arbitrage
##
@view
func get_base_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pair1 : Pair, pair2 : Pair
) -> (base_token : felt):
    alloc_locals
    # Verify that token0 < token1 and both pairs have the same tokens
    assert_le(pair1.token0, pair1.token1)
    assert pair1.token0 = pair2.token0
    assert pair1.token1 = pair2.token1

    let (is_token0_base) = arbitrage_tokens.read(pair1.token0)
    let (is_token1_base) = arbitrage_tokens.read(pair1.token1)

    # Verify that at least one of the two tokens is a base token
    assert_not_zero(is_token0_base + is_token1_base)
    local base_token
    if is_token0_base == TRUE:
        base_token = pair1.token0
    else:
        base_token = pair1.token1
    end

    return (base_token)
end

# Returns 1 if value != 0. Returns 0 otherwise.
func is_zero(value) -> (res):
    if value == 0:
        return (res=1)
    end

    return (res=0)
end

func get_ordered_values{range_check_ptr}(value1, value2) -> (lower : felt, higher : felt):
    alloc_locals  # otherwise revoked
    let (is_v1_gt_v2) = is_le(value1, value2)
    if is_v1_gt_v2 == TRUE:
        return (value2, value1)
    end
    return (value1, value2)
end

##
# Compares the price in quote tokens of base_token
# Returns the higher/lower pair and if token0 is a base token
# #
func get_ordered_pairs{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pair1 : Pair, pair2 : Pair
) -> (lower_pair : Pair, higher_pair : Pair, ordered_reserves : OrderedReserves):
    alloc_locals
    local range_check_ptr = range_check_ptr
    let (base_token) = get_base_token(pair1, pair2)
    let (is_base_token0) = is_zero(base_token - pair1.token0)  # =TRUE if base=token0, because we always have token0<token1

    local price0_temp  # I have to use a "temp" var because I can't re-allocate local variable price0 once it's already done
    local price1_temp
    local price0
    local price1
    local remainder0
    local remainder1
    local pair1_denominator  # in case of quotient = 0 and remainder0=remainder1
    local pair2_denominator

    # Get the price of the base tokens in quote_tokens
    # Price in in quote_tokens is base/quote hence reserve1/0 / reserve0/1
    if is_base_token0 == TRUE:
        let (res0, rem0) = unsigned_div_rem(pair1.reserve1, pair1.reserve0)
        let (res1, rem1) = unsigned_div_rem(pair2.reserve1, pair2.reserve0)
        price0_temp = res0
        price1_temp = res1
        remainder0 = rem1
        remainder1 = rem0
        pair1_denominator = pair1.reserve0
        pair2_denominator = pair2.reserve0
    else:
        let (res0, rem0) = unsigned_div_rem(pair1.reserve0, pair1.reserve1)
        let (res1, rem1) = unsigned_div_rem(pair2.reserve0, pair2.reserve1)
        price0_temp = res0
        price1_temp = res1
        remainder0 = rem0
        remainder1 = rem1
        pair1_denominator = pair1.reserve1
        pair2_denominator = pair2.reserve1
    end

    # todo edge case when remainder0 = remainder1 and price is 0 :)
    # > Verify which reserve is the biggest one

    # todo manage sub-0 prices w/ remainders
    # let (is_price0_notzero) = is_not_zero(price0_temp)
    # let (is_price1_notzero) = is_not_zero(price1_temp)
    let (are_prices_equal) = is_zero(price0_temp - price1_temp)

    # Not inside the "ifs" because otherwise the reference to range_check_ptr gets revoked
    let (is_remain1_eq_remain2) = is_zero(remainder0 - remainder1)
    let (v1, v2) = get_ordered_values(pair1_denominator, pair2_denominator)

    # let (is_price0_gt_1) = is_nn(price0)
    # let (is_price1_gt_1) = is_nn(price1)

    # both are not zero => compare prices
    # todo refactor in a better way
    if are_prices_equal == TRUE:
        if is_remain1_eq_remain2 == TRUE:
            price0 = v2 #we need to invert here, because the price is inversely propotional to the denominator
            price1 = v1
        else:
            price0 = remainder0
            price1 = remainder1
        end
    else:
        price0 = price0_temp
        price1 = price1_temp
    end

    # no need to handle the case where price0 is 0 and price1 > 1 because it's obviously higher
    # if (is_price0_zero+is_price1_gt_1) == 2:
    #     price0 = price0 - 1
    #     price1 = price1 - 1
    # end

    local lower_pair : Pair
    local higher_pair : Pair

    # Get the higher/lower pair based on prices
    let (is_le_price0_price1) = is_le(price0, price1)  # base token cheaper on pair 0
    if is_le_price0_price1 == TRUE:
        # lower
        assert lower_pair = pair1  # instr to "copy" one struct into another, unallocated one
        assert higher_pair = pair2
    else:
        assert lower_pair = pair2
        assert higher_pair = pair1
    end

    # Get a1,b2,a2,b2 parameters based on pairs
    # a is quote token, b is base token
    local ordered_reserves : OrderedReserves
    if is_base_token0 == TRUE:
        ordered_reserves.a1 = lower_pair.reserve1
        ordered_reserves.b1 = lower_pair.reserve0
        ordered_reserves.a2 = higher_pair.reserve1
        ordered_reserves.b2 = higher_pair.reserve0
    else:
        ordered_reserves.a1 = lower_pair.reserve0
        ordered_reserves.b1 = lower_pair.reserve1
        ordered_reserves.a2 = higher_pair.reserve0
        ordered_reserves.b2 = higher_pair.reserve1
    end

    return (lower_pair, higher_pair, ordered_reserves)
end

func get_profit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    pair1 : Pair, pair2 : Pair
) -> (profit : felt, base_token : felt):
    alloc_locals  # otherwise syscall_ptr is not revoked
    let (_, _, ordered_reserves) = get_ordered_pairs(pair1, pair2)

    let (optimal_amt) = calc_optimal_amount(ordered_reserves)

    #How to get profit : Call getAmountsOut w/ optimal amount, call getAmountsIn w/ swap result, then call getAmountsOut w/ tokens to repay
    # profit is the difference between the last two calls

    let profit = 0
    let base_token = 0

    return (profit, base_token)
end
##
# Given 2 pool pairs characterized by reserve0 and reserve1, returns the optimal amount of token to use for arbitrage.
##
func calc_optimal_amount{range_check_ptr}(ordered_reserves : OrderedReserves) -> (amount : felt):
    # Only working with 18 decimals for now. But we'll run into an overflow problem if we use all 18 decimals for our calculation.
    # For that matter we'll remove as much useless decimals as possible while keeping a correct precision.

    # If we run the calculation with the reserves amount, we'll have problems with overflow
    alloc_locals  # if removed = divider ref refoked ?
    let (divider) = find_reserve_divider(ordered_reserves)
    let (a1, _) = unsigned_div_rem(ordered_reserves.a1, divider)
    let (a2, _) = unsigned_div_rem(ordered_reserves.a2, divider)
    let (b1, _) = unsigned_div_rem(ordered_reserves.b1, divider)
    let (b2, _) = unsigned_div_rem(ordered_reserves.b2, divider)

    # quadratic equation ax^2 + bx + c with a,b,c :
    tempvar a = a1 * b1 - a2 * b2
    tempvar b = 2 * b1 * b2 * (a1 + a2)
    tempvar c = b1 * b2 * (a1 * b2 - a2 * b1)

    # solve equation
    let (x1, x2) = solve_quadratic_equation(a, b, c)
    let x1 = x1 * divider
    let x2 = x2 * divider
    let (best_amt) = lowest_valid_root(x1, x2, ordered_reserves.b1, ordered_reserves.b2)
    return (best_amt)
end

# TODO Implement a method to dynamically check which reserve is smaller

##
# Finds the divider to use for the calculation of the optimal amount.
# The divider is the smallest number that can be used to divide the reserves of the 2 pools without losing precision.
# In our case, we'll have a precision ok 4 decimals
##
func find_reserve_divider{range_check_ptr}(ordered_reserves : OrderedReserves) -> (
    lowest_reserve : felt
):
    alloc_locals
    let a1 = ordered_reserves.a1
    let a2 = ordered_reserves.a2
    let b1 = ordered_reserves.b1
    let b2 = ordered_reserves.b2

    # Start by determining which reserve is the smallest
    let (is_le_a1_b1) = is_le(a1, b1)
    let (is_le_a2_b2) = is_le(a2, b2)

    local min1 : felt
    local min2 : felt

    if is_le_a1_b1 == TRUE:
        min1 = a1
    else:
        min1 = b1
    end
    if is_le_a2_b2 == TRUE:
        min2 = a2
    else:
        min2 = b2
    end

    let (is_le_min1_min2) = is_le(min1, min2)
    local min_reserve : felt

    if is_le_min1_min2 == TRUE:
        min_reserve = min1
    else:
        min_reserve = min2
    end

    # We'll use the smallest reserve to determine the divider
    let (divider) = _find_divider(min_reserve, 10 ** 24)
    return (divider)
end

##
# Recursive function to find the divider to use for the calculation of the optimal amount.
##
func _find_divider{range_check_ptr}(min_reserve : felt, threshold : felt) -> (divider : felt):
    alloc_locals
    # We'll slowly decrease the threshold until we find a suitable one

    let (local is_divider_le) = is_le(threshold, min_reserve)
    let (local is_threshold_low) = is_le(threshold, 10 ** 6)  # downside limit to threshold
    let stop_recursion = is_divider_le + is_threshold_low  # stop recursion if (a OR b)

    if stop_recursion == FALSE:
        return _find_divider(min_reserve, threshold / 10)
    else:
        return (threshold / 10000)  # divider is the threshold / 10000 to ensure a precision of 4
    end
end

##
# Solves a quadratic equation, returning only reals, whether positive or negative.
##
func solve_quadratic_equation{range_check_ptr}(a : felt, b : felt, c : felt) -> (
    x1 : felt, x2 : felt
):
    alloc_locals
    tempvar delta = (b * b) - 4 * (a * c)
    # Verify that the equation has real roots
    with_attr error_message("Equation doesn't have a root in reals"):
        assert_nn(delta)
    end

    let (sqrt_delta) = sqrt(delta)

    local x1 = ((-b) - sqrt_delta) / (2 * a)
    local x2 = ((-b) + sqrt_delta) / (2 * a)
    return (x1, x2)
end

##
# Returns the lowest of the two roots if they're valid solution
# #
func lowest_valid_root{range_check_ptr}(x1, x2, b1, b2) -> (x : felt):
    alloc_locals
    let (x1_not_zero) = is_not_zero(x1)
    let (x1_nn) = is_nn(x1)
    let (x1_le_b1) = is_le(x1, b1)
    let (x1_le_b2) = is_le(x1, b2)

    let (x2_not_zero) = is_not_zero(x2)
    let (x2_nn) = is_nn(x2)
    let (x2_le_b1) = is_le(x2, b2)
    let (x2_le_b2) = is_le(x2, b2)

    tempvar x1_ok = (x1_not_zero * x1_nn * x1_le_b1 * x1_le_b2)  # (x1!=0 && x1>=0 && x1<=b1 && x1<=b2)
    tempvar x2_ok = (x2_not_zero * x2_nn * x2_le_b1 * x2_le_b2)

    # 0<x<b1 and 0<x<b2
    with_attr error_message("Incorrect input"):
        assert_not_zero(x1_ok + x2_ok)  # verify that x1_ok OR x2_ok == TRUE
    end

    # x1_ok will always be lower than x2_ok, forAll (a,b,c), (-sqrt(delta) < + sqrt(delta))
    if x1_ok == TRUE:
        return (x1)
    else:
        return (x2)
    end
end

%lang starknet

from starkware.cairo.common.math import assert_nn, sqrt, assert_not_zero, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_not_zero, is_nn, is_le
from starkware.cairo.common.bool import TRUE, FALSE

struct Pair:
    member reserve_0 : felt
    member reserve_1 : felt
end

##
# Given 2 pool pairs characterized by reserve_0 and reserve_1, returns the optimal amount of token to use for arbitrage.
##
@view
func calc_optimal_amount{range_check_ptr}(pair1 : Pair, pair2 : Pair) -> (amount : felt):
    # Only working with 18 decimals for now. But we'll run into an overflow problem if we use all 18 decimals for our calculation.
    # For that matter we'll remove as much useless decimals as possible while keeping a correct precision.

    # If we run the calculation with the reserves amount, we'll have problems with overflow
    alloc_locals

    let (divider) = find_reserve_divider(pair1, pair2)
    let (a1, _) = unsigned_div_rem(pair1.reserve_0, divider)
    let (a2, _) = unsigned_div_rem(pair2.reserve_0, divider)
    let (b1, _) = unsigned_div_rem(pair1.reserve_1, divider)
    let (b2, _) = unsigned_div_rem(pair2.reserve_1, divider)

    # quadratic equation ax^2 + bx + c with a,b,c :
    tempvar a = a1 * b1 - a2 * b2
    tempvar b = 2 * b1 * b2 * (a1 + a2)
    tempvar c = b1 * b2 * (a1 * b2 - a2 * b1)

    # solve equation
    let (x1, x2) = solve_quadratic_equation(a, b, c)
    let x1 = x1 * divider
    let x2 = x2 * divider
    let (best_amt) = lowest_valid_root(x1, x2, pair1.reserve_1, pair2.reserve_1)
    return (best_amt)
end

##
# Finds the divider to use for the calculation of the optimal amount.
# The divider is the smallest number that can be used to divide the reserves of the 2 pools without losing precision.
# In our case, we'll have a precision ok 4 decimals
##
func find_reserve_divider{range_check_ptr}(pair1 : Pair, pair2 : Pair) -> (lowest_reserve : felt):
    alloc_locals
    let a1 = pair1.reserve_0
    let a2 = pair2.reserve_0
    let b1 = pair1.reserve_1
    let b2 = pair2.reserve_1

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
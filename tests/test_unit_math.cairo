%lang starknet

from src.Arbitrageur import (
    solve_quadratic_equation,
    lowest_valid_root,
    calc_optimal_amount,
    _find_divider,
    find_reserve_divider,
)

from lib.utils import parse_units
from lib.DataTypes import Pair, OrderedReserves

from starkware.cairo.common.pow import pow
from starkware.cairo.common.math import assert_in_range, assert_le

const token0 = 42
const token1 = 1337

@view
func test_quadratic_solving_ok{range_check_ptr}():
    alloc_locals
    local vars_1 : (felt, felt, felt) = (1, -2, 1)
    let (x1, x2) = solve_quadratic_equation(vars_1[0], vars_1[1], vars_1[2])
    assert x1 = 1
    assert x2 = 1

    local vars_2 : (felt, felt, felt) = (1, -18, 81)
    let (x1, x2) = solve_quadratic_equation(vars_2[0], vars_2[1], vars_2[2])
    assert x1 = 9
    assert x2 = 9

    local vars_3 : (felt, felt, felt) = (-40000000, 160000000, 200000000)
    # %{ expect_revert(error_message="Equation doesn't have a root in reals") %}
    let (x1, x2) = solve_quadratic_equation(vars_3[0], vars_3[1], vars_3[2])
    assert x1 = 5
    assert x2 = -1
    return ()
end

@view
func test_best_amount_ok{range_check_ptr}():
    alloc_locals

    # x2 < b1 && x2 < b2 => pass
    let x1 = 12923
    let x2 = 12
    let b1 = 100
    let b2 = 100

    let (best_amount) = lowest_valid_root(x1, x2, b1, b2)
    assert best_amount = 12

    # x1 < x2 &&
    # x1 < b1 && x2 < b2 => pass
    let x1 = 1203
    let x2 = 12123
    let b1 = 1000000
    let b2 = 1000000
    let (best_amount) = lowest_valid_root(x1, x2, b1, b2)
    assert best_amount = 1203
    return ()
end

@view
func test_best_amount_insufficient_liq{range_check_ptr}():
    alloc_locals

    # x1 > b1
    let x1 = 1203
    let x2 = 2012
    let b1 = 1000
    let b2 = 1600
    %{ expect_revert() %}
    let (best_amount) = lowest_valid_root(x1, x2, b1, b2)
    return ()
end

@view
func test_optimal_amount{range_check_ptr}():
    alloc_locals
    let (local format_decimals) = pow(10, 18)
    let (a1) = parse_units(5000, 18)
    let (b1) = parse_units(10, 18)
    let (a2) = parse_units(6000, 18)
    let (b2) = parse_units(10, 18)
    let ordered_reserves = OrderedReserves(a1, b1, a2, b2)  # ordered with pair1 = lower_pair, pair2=higher_pair
    let (amount) = calc_optimal_amount(ordered_reserves)
    # a = - 10000, b= 2200000, c =-1000000

    # smallest root should be something around x≈0.45549
    # remember that we're operating w/ 18 decimals
    assert_in_range(amount, 4554 * 10 ** 14, 4555 * 10 ** 14)
    return ()
end

@view
func test_optimal_amount_ko{range_check_ptr}():
    alloc_locals
    let (local format_decimals) = pow(10, 18)
    let (a1) = parse_units(6000, 18)
    let (b1) = parse_units(10, 18)
    let (a2) = parse_units(5000, 18)
    let (b2) = parse_units(10, 18)
    let ordered_reserves = OrderedReserves(a1, b1, a2, b2)  # wrong order because price(pair1) > price(pair2)
    %{ expect_revert(error_message="Incorrect input") %}
    let (amount) = calc_optimal_amount(ordered_reserves)
    return ()
end

@view
func test_find_divider{range_check_ptr}():
    # `whole` tokens
    let (format_decimals) = pow(10, 18)
    let a1 = 5000 * format_decimals  # 5000 * 10^18 = 5 * 10^22
    let (divider) = _find_divider(a1, 10 ** 24)
    assert divider = 10 ** 17

    # `decimal` tokens
    let a2 = 1 * 10 ** 13  # 0.00001 units
    let (divider) = _find_divider(a2, 10 ** 24)
    assert divider = 10 ** 9
    return ()
end

@view
func test_find_reserve_divider{range_check_ptr}():
    alloc_locals
    let (a1) = parse_units(5089, 18)
    let (b1) = parse_units(148, 18)
    let (a2) = parse_units(2019, 18)
    let (b2) = parse_units(139, 18)
    let pair1 = Pair(token0, token1, a1, b1)  # 5k tokens with 18 decimals
    let pair2 = Pair(token0, token1, a2, b2)  # 6k tokens with 18 decimals
    let ordered_reserves = OrderedReserves(a1, b1, a2, b2)  # ordered with pair1 = lower_pair, pair2=higher_pair
    let (divider) = find_reserve_divider(ordered_reserves)

    assert divider = 10 ** 16
    return ()
end

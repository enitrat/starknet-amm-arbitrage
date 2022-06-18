%lang starknet
from src.Arbitrageur import (
    calc_optimal_amount,
    add_base_token,
    get_base_token,
    get_ordered_pairs,
    get_profit,
    get_amount_out,
    get_amount_in,
)
from lib.DataTypes import Pair, OrderedReserves
from lib.utils import parse_units
from starkware.cairo.common.cairo_builtins import HashBuiltin

const token_x = 42
const token_y = 1337
const token_high = 999999

@view
func test_json{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    add_base_token(token_y)
    local tests_len : felt
    %{
        SCENARIO_PATH = "./tests/scenarios/scenario_unit_arbitrage.json"
        import json
        f = open(SCENARIO_PATH, "r")
        my_tests = json.load(f)
        test_case = my_tests["test_get_ordered_tokens"]
        tests = test_case["tests"]
        ids.tests_len = len(tests)
    %}
    _test_json(tests_len)
    return ()
end

func _test_json{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tests_len : felt
):
    alloc_locals
    if tests_len == 0:
        return ()
    end
    local inputs : felt*
    local outputs : felt*
    %{
        test_id = len(tests)-ids.tests_len
        print(tests[test_id]["description"])
        ids.inputs = inputs = segments.add()
        PRIME = 2 ** 251 + 17 * 2 ** 192 + 1 #Required for negative integer values
        for i,val in enumerate(tests[test_id]['inputs']):
            memory[inputs+i] = val % PRIME

        ids.outputs=outputs=segments.add()
        for i,val in enumerate(tests[test_id]['outputs']):
            memory[outputs+i] = val % PRIME
    %}
    let pair1 = Pair(inputs[0], inputs[1], inputs[2], inputs[3])
    let pair2 = Pair(inputs[0], inputs[1], inputs[4], inputs[5])
    let (lower_pair, higher_pair, ordered_reserves) = get_ordered_pairs(pair1, pair2)
    local expected_lower : Pair
    local expected_higher : Pair
    if outputs[0] == 1:
        assert expected_lower = pair1
        assert expected_higher = pair2
    else:
        assert expected_lower = pair2
        assert expected_higher = pair1
    end
    assert ordered_reserves = OrderedReserves(outputs[1], outputs[2], outputs[3], outputs[4])
    return _test_json(tests_len - 1)
end

@view
func test_base_token_ok{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    # let (_, _, arbitrageur) = get_contract_addresses()

    # Base token is token_y && token order 1
    add_base_token(token_y)
    let pair1 = Pair(token_x, token_y, 0, 0)
    let pair2 = Pair(token_x, token_y, 0, 0)
    let (base_token) = get_base_token(pair1, pair2)
    assert base_token = token_y

    # Base token is token_y && token order 2
    let pair1 = Pair(token_y, token_high, 0, 0)
    let pair2 = Pair(token_y, token_high, 0, 0)
    let (base_token) = get_base_token(pair1, pair2)
    assert base_token = token_y
    return ()
end

@view
func test_base_token_ko_no_base_token{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    # Wrong token order
    let pair1 = Pair(token_y, token_high, 0, 0)
    let pair2 = Pair(token_y, token_high, 0, 0)
    %{ expect_revert() %}
    let (base_token) = get_base_token(pair1, pair2)
    return ()
end

@view
func test_base_token_ko_token_order{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    # Wrong token order because address token_y> addrestoken_xs
    add_base_token(token_y)
    let pair1 = Pair(token_y, token_x, 0, 0)
    let pair2 = Pair(token_y, token_y, 0, 0)
    %{ expect_revert() %}
    let (base_token) = get_base_token(pair1, pair2)
    return ()
end

@view
func test_get_profit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    add_base_token(token_y)  # base token is token1
    let (local p1r0) = parse_units(6000, 18)
    let (p1r1) = parse_units(10, 18)
    let (p2r0) = parse_units(5000, 18)
    let (p2r1) = parse_units(10, 18)

    # pair1 has a lower price quote/base than pair2
    let pair1 = Pair(token_x, token_y, p1r0, p1r1)
    let pair2 = Pair(token_x, token_y, p2r0, p2r1)
    let (profit, profit_rate) = get_profit(pair1, pair2)
    %{ print("profit : ",ids.profit*10**-18, "profit_rate : ", ids.profit_rate/1000) %}
    return ()
end

@view
func test_get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    let (amount_out) = parse_units(600, 18)
    let (reserve_in) = parse_units(10, 18)
    let (reserve_out) = parse_units(6000, 18)
    let (output) = get_amount_in(amount_out, reserve_in, reserve_out)
    assert output = 1111100000000000000  # makes sense
    return ()
end

@view
func test_get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    let (amount_in) = parse_units(600, 18)
    let (reserve_in) = parse_units(5000, 18)
    let (reserve_out) = parse_units(10, 18)
    let (output) = get_amount_out(amount_in, reserve_in, reserve_out)
    assert output = 9836065573770491803  # makes sense
    return ()
end

# @view
# func test_get_ordered_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
#     add_base_token(token_y)
#     # ## with price > 0
#     # order 1 && base is token1
#     let pair1 = Pair(token_x, token_y, 5000, 10)  # lower 1b = 500a
#     let pair2 = Pair(token_x, token_y, 6000, 10)  # higher 1b = 600a
#     let (lower_pair, higher_pair, ordered_reserves) = get_ordered_pairs(pair1, pair2)
#     assert lower_pair = pair1
#     assert higher_pair = pair2
#     assert ordered_reserves = OrderedReserves(5000, 10, 6000, 10)

# # order 2
#     let pair1 = Pair(token_x, token_y, 6000, 10)  # higher 1b = 600a
#     let pair2 = Pair(token_x, token_y, 5000, 10)  # lower 1b = 500a
#     let (lower_pair, higher_pair, ordered_reserves) = get_ordered_pairs(pair1, pair2)
#     assert lower_pair = pair2
#     assert higher_pair = pair1
#     assert ordered_reserves = OrderedReserves(5000, 10, 6000, 10)

# # base istoken0
#     let pair1 = Pair(token_y, token_high, 10, 6000)  # higher 1b = 600a
#     let pair2 = Pair(token_y, token_high, 10, 5000)  # lower 1b = 500a
#     let (lower_pair, higher_pair, ordered_reserves) = get_ordered_pairs(pair1, pair2)
#     assert lower_pair = pair2
#     assert higher_pair = pair1
#     assert ordered_reserves = OrderedReserves(5000, 10, 6000, 10)

# # ## With price < 0
#     # and equal remainders
#     let pair1 = Pair(token_x, token_y, 10, 5000)  # higher 1b = 1/500a
#     let pair2 = Pair(token_x, token_y, 10, 6000)  # lower 1b = 1/600a
#     let (lower_pair, higher_pair, ordered_reserves) = get_ordered_pairs(pair1, pair2)
#     assert lower_pair = pair2
#     assert higher_pair = pair1
#     assert ordered_reserves = OrderedReserves(10, 5000, 10, 6000)

# # and non-equal remainders
#     let pair1 = Pair(token_x, token_y, 100, 5000)  # higher 1b = 1/50a
#     let pair2 = Pair(token_x, token_y, 10, 6000)  # lower 1b = 1/600a
#     let (lower_pair, higher_pair, ordered_reserves) = get_ordered_pairs(pair1, pair2)
#     assert lower_pair = pair2
#     assert higher_pair = pair1
#     assert ordered_reserves = OrderedReserves(10, 6000, 100, 5000)

# # ## With one price>0, one price <0
#     let pair1 = Pair(token_y, token_high, 1000, 10)  # higher 1b = 1/100a
#     let pair2 = Pair(token_y, token_high, 10, 6000)  # lower 1b = 600a
#     let (lower_pair, higher_pair, ordered_reserves) = get_ordered_pairs(pair1, pair2)
#     assert lower_pair = pair1
#     assert higher_pair = pair2
#     assert ordered_reserves = OrderedReserves(10, 1000, 6000, 10)
#     return ()
# end

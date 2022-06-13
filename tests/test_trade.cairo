%lang starknet

from src.IPair import IPair
from src.basic_arbitrage import Pair, calc_optimal_amount
from lib.utils import parse_units
from starkware.cairo.common.math import assert_in_range
# Setup a test with an active reserve for test_token
@view
func __setup__{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals
    %{
        context.pair_1 = deploy_contract("./src/mock_pair.cairo").contract_address

        context.pair_2 = deploy_contract("./src/mock_pair.cairo").contract_address
    %}
    local pair_1
    local pair_2
    %{ ids.pair_1 = context.pair_1 %}
    %{ ids.pair_2 = context.pair_2 %}

    let (x1) = parse_units(5000, 18)
    let (y1) = parse_units(10, 18)
    let (x2) = parse_units(6000, 18)
    let (y2) = parse_units(10, 18)

    IPair.set_reserves(pair_1, x1, y1)
    IPair.set_reserves(pair_2, x2, y2)
    return ()
end

func get_contract_addresses() -> (pair_1 : felt, pair_2 : felt):
    tempvar pair_1
    tempvar pair_2
    %{ ids.pair_1 = context.pair_1 %}
    %{ ids.pair_2 = context.pair_2 %}
    return (pair_1, pair_2)
end

@view
func test_correct_amount{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals
    local syscal_ptr : felt* = syscall_ptr
    let (pair_1, pair_2) = get_contract_addresses()

    # Get dex reserves and fee
    let (x1, y1) = IPair.get_reserves(pair_1)
    let (x2, y2) = IPair.get_reserves(pair_2)

    # Find most optimised one
    let (amount) = calc_optimal_amount(Pair(x1, y1), Pair(x2, y2))
    assert_in_range(amount, 4554 * 10 ** 14, 4555 * 10 ** 14)
    return ()
end

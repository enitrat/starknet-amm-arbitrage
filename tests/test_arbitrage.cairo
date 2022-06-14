%lang starknet

from src.IAmm import IAmm
from lib.utils import parse_units
from starkware.cairo.common.math import assert_in_range, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.bool import TRUE, FALSE
# Setup a test with an active reserve for test_token
from src.basic_arbitrage import calc_optimal_amount, Pair

const TOKEN_A = 42
const TOKEN_B = 1337

@view
func __setup__{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals
    %{
        context.amm1 = deploy_contract("./src/mock_amm.cairo").contract_address
        context.amm2 = deploy_contract("./src/mock_amm.cairo").contract_address
    %}
    local amm1
    local amm2
    %{ ids.amm1 = context.amm1 %}
    %{ ids.amm2 = context.amm2 %}

    let (a1) = parse_units(5000, 18)
    let (b1) = parse_units(10, 18)
    let (a2) = parse_units(6000, 18)
    let (b2) = parse_units(10, 18)

    # Fill AMM reserves with arbitrage opportunities
    IAmm.set_reserves(amm1, TOKEN_A, TOKEN_B, a1, b1)
    IAmm.set_reserves(amm2, TOKEN_A, TOKEN_B, a2, b2)

    # Fill AMM user balance

    let (balance_a_1) = parse_units(10, 18)  # 10 / 5000 total
    let (balance_b_1) = parse_units(10, 16)  # 0.01 / 10 total
    let (balance_a_2) = parse_units(10, 18)  # 10 / 5000 total
    let (balance_b_2) = parse_units(10, 16)  # 0.01 / 10 total

    IAmm.set_user_balance(amm1, TOKEN_A, balance_a_1)
    IAmm.set_user_balance(amm1, TOKEN_B, balance_b_1)
    IAmm.set_user_balance(amm2, TOKEN_A, balance_a_2)
    IAmm.set_user_balance(amm2, TOKEN_B, balance_b_2)
    return ()
end

func get_contract_addresses() -> (amm1 : felt, amm2 : felt):
    tempvar amm1
    tempvar amm2
    %{ ids.amm1 = context.amm1 %}
    %{ ids.amm2 = context.amm2 %}
    return (amm1, amm2)
end

@view
func test_arbitrage{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals
    local syscall_ptr : felt* = syscall_ptr
    let (amm1, amm2) = get_contract_addresses()

    let (reserve1, reserve2, inversed) = IAmm.get_reserves(amm1, TOKEN_A, TOKEN_B)
    let pair_0 = Pair(reserve1, reserve2)

    let (reserve1, reserve2, inversed) = IAmm.get_reserves(amm2, TOKEN_A, TOKEN_B)
    let pair_1 = Pair(reserve1, reserve2)

    let (optimal_amt) = calc_optimal_amount(pair_0, pair_1)

    # TODO Implement a method to dynamically check which reserve is smaller
    # Here, we know that we'll do B=>A in pool2, A=>B in pool1 and sell init_b in pool2 to keep the difference
    let (balance_a) = IAmm.get_user_balance(amm1, TOKEN_A)
    let (balance_b) = IAmm.get_user_balance(amm1, TOKEN_B)
    local swap_amount : felt
    let (is_balance_higher) = is_le(optimal_amt, balance_b)
    if is_balance_higher == TRUE:
        swap_amount = optimal_amt
    else:
        swap_amount = balance_b
    end

    # Sell swap_amount b tokens to get a tokens
    let (temp_a) = IAmm.swap(amm2, TOKEN_B, TOKEN_A, swap_amount)
    # Sell all received a_tokens to get b_tokens
    let (temp_b) = IAmm.swap(amm1, TOKEN_A, TOKEN_B, temp_a)
    # Repay first swap and keep the difference
    IAmm.swap(amm2, TOKEN_B, TOKEN_A, swap_amount)
    let profit_b = temp_b - swap_amount
    let (profit_percent_e3, _) = unsigned_div_rem((profit_b) * 100 * 10 ** 3, (balance_b))
    assert_in_range(profit_percent_e3, 17400, 17500)
    %{ print(" Profit : ", ids.profit_percent_e3, "e-3 %") %}
    %{ print(" Profit : ", ids.profit_b*10**-18, "tokens ") %}

    return ()
end

%lang starknet

from src.IAmm import IAmm
from src.IArbitrageur import IArbitrageur
from lib.utils import parse_units
from starkware.cairo.common.math import assert_in_range, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
# Setup a test with an active reserve for test_token
from src.Arbitrageur import calc_optimal_amount, add_base_token, get_base_token
from lib.DataTypes import Pair, OrderedReserves

const token0 = 42
const token1 = 1337
const token_high = 999999

@view
func __setup__{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals
    # Deploy AMM
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
    IAmm.set_reserves(amm1, token0, token1, a1, b1)
    IAmm.set_reserves(amm2, token0, token1, a2, b2)

    # Fill AMM user balance

    let (balance_a_1) = parse_units(10, 18)  # 10 / 5000 total
    let (balance_b_1) = parse_units(10, 17)  # 0.01 / 10 total
    let (balance_a_2) = parse_units(10, 18)  # 10 / 6000 total
    let (balance_b_2) = parse_units(10, 17)  # 0.01 / 10 total

    IAmm.set_user_balance(amm1, token0, balance_a_1)
    IAmm.set_user_balance(amm1, token1, balance_b_1)
    IAmm.set_user_balance(amm2, token0, balance_a_2)
    IAmm.set_user_balance(amm2, token1, balance_b_2)

    # Deploy Arbitrageur
    %{ context.arbitrageur = deploy_contract("./src/Arbitrageur.cairo").contract_address %}
    # local arbitrageur
    # %{ ids.arbitrageur= context.arbitrageur %}
    # IArbitrageur.add_base_token(arbitrageur, token1)  # We want to arbitrage agains token1
    return ()
end

func get_contract_addresses() -> (amm1 : felt, amm2 : felt, arbitrageur : felt):
    tempvar amm1
    tempvar amm2
    tempvar arbitrageur
    %{ ids.amm1 = context.amm1 %}
    %{ ids.amm2 = context.amm2 %}
    %{ ids.arbitrageur= context.arbitrageur %}
    return (amm1, amm2, arbitrageur)
end

@view
func test_arbitrage{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals
    local syscall_ptr : felt* = syscall_ptr
    let (amm1, amm2, _) = get_contract_addresses()

    let (reserve0, reserve1, inversed) = IAmm.get_reserves(amm1, token0, token1)
    let pair_0 = Pair(token0, token1, reserve0, reserve1)
    let a1 = reserve0
    let b1 = reserve1
    let (reserve0, reserve1, inversed) = IAmm.get_reserves(amm2, token0, token1)
    let pair_1 = Pair(token0, token1, reserve0, reserve1)

    let a2 = reserve0
    let b2 = reserve1
    let ordered_reserves = OrderedReserves(a1, b1, a2, b2)

    let (optimal_amt) = calc_optimal_amount(ordered_reserves)
    %{ print(ids.optimal_amt*10**-18) %}

    # TODO Implement a method to dynamically check which reserve is smaller
    # Here, we know that we'll do B=>A in pool2, A=>B in pool1 and  to keep the difference
    let (balance_a) = IAmm.get_user_balance(amm1, token0)
    let (balance_b) = IAmm.get_user_balance(amm1, token1)
    local swap_amount : felt
    let (is_balance_higher) = is_le(optimal_amt, balance_b)
    if is_balance_higher == TRUE:
        swap_amount = optimal_amt
    else:
        swap_amount = balance_b
    end

    %{ print(ids.swap_amount*10**-18) %}

    # Sell swap_amount b tokens to get a tokens
    let (temp_quote) = IAmm.swap(amm2, token1, token0, swap_amount)
    # Sell all received a_tokens to get b_tokens
    let (total_base) = IAmm.swap(amm1, token0, token1, temp_quote)
    # Repay first swap and keep the difference
    %{ print(ids.temp_quote*10**-18) %}
    %{ print(ids.total_base*10**-18) %}
    let profit_b = total_base - swap_amount
    # let (profit_percent_e3, _) = unsigned_div_rem((profit_b) * 100 * 10 ** 3, (balance_b))
    # assert_in_range(profit_percent_e3, 17400, 17500)
    %{ print(" Profit % : ", ids.profit_b * 100 /ids.swap_amount , "%") %}
    %{ print(" Profit : ", ids.profit_b*10**-18, "tokens ") %}

    return ()
end

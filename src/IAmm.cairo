%lang starknet

@contract_interface
namespace IAmm:
    func get_reserves(token0 : felt, token1 : felt) -> (
        reserve0 : felt, reserve2 : felt, inversed : felt
    ):
    end

    func set_reserves(token0 : felt, token1 : felt, reserve0 : felt, reserve1 : felt):
    end

    func set_user_balance(token : felt, amount : felt):
    end

    func get_user_balance(token : felt) -> (balance : felt):
    end

    func add_token(token:felt):
    end

    func swap(token_from : felt, token_to : felt, amount : felt) -> (res : felt):
    end

    func get_amount_in(amount_out : felt, reserve_in : felt, reserve_out : felt) -> (res : felt):
    end

    func get_amount_out(amount_in : felt, reserve_in : felt, reserve_out : felt) -> (res : felt):
    end
end

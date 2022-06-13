%lang starknet

@contract_interface
namespace IPair:
    func get_reserves() -> (reserve_1 : felt, reserve2 : felt):
    end

    func set_reserves(_reserve_1 : felt, _reserve_2 : felt):
    end

    func trade(_trade_amount : felt) -> (trade_return : felt):
    end
end

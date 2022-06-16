%lang starknet

from lib.DataTypes import Pair

@contract_interface
namespace IArbitrageur:
    func add_base_token(token : felt):
    end

    func remove_base_token(token : felt):
    end

    func get_base_token(pair1 : Pair, pair2 : Pair) -> (base_token : felt):
    end
end

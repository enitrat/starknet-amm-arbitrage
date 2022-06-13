%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.math import unsigned_div_rem

struct Pair:
    member reserve_1 : felt
    member reserve_2 : felt
end

@storage_var
func _pair() -> (pair : Pair):
end

@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve1 : felt, reserve2 : felt
):
    let (pair : Pair) = _pair.read()
    return (pair.reserve_1, pair.reserve_2)
end

@external
func set_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _reserve_1 : felt, _reserve_2 : felt
):
    _pair.write(Pair(_reserve_1, _reserve_2))

    return ()
end

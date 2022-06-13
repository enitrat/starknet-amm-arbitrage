

from starkware.cairo.common.pow import pow

func parse_units{range_check_ptr}(amount:felt,decimals:felt)->(res:felt):
    let (x) = pow(10,decimals)
    return (amount * x)
end
# :nodoc:
macro __mul_impl(name, type, n)
  # :nodoc:
  fun {{name}}(a : {{type}}, b : {{type}}, overflow : Int32*) : {{type}}
    n = {{n}}
    min = {{type}}::MIN
    max = {{type}}::MAX
    overflow.value = 0
    result = a &* b
    if a == min
      if b != 0 && b != 1
        overflow.value = 1
      end
      return result
    end
    if b == min
      if a != 0 && a != 1
        overflow.value = 1
      end
      return result
    end
    sa = a >> (n &- 1)
    abs_a = (a ^ sa) &- sa
    sb = b >> (n &- 1)
    abs_b = (b ^ sb) &- sb
    if abs_a < 2 || abs_b < 2
      return result
    end
    if sa == sb
      if abs_a > max // abs_b
        overflow.value = 1
      end
    else
      if abs_a > min // ({{type}}.new(0) &- abs_b)
        overflow.value = 1
      end
    end
    return result
  end
end

__mul_impl(__mulosi4, Int32, 32)
__mul_impl(__mulodi4, Int64, 64)
__mul_impl(__muloti4, Int128, 128)

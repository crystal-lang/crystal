# :nodoc:
private macro __mul_impl(name, type, n)
  # :nodoc:
  # Ported from https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/lib/builtins/int_mulo_impl.inc
  fun {{name}}(a : {{type}}, b : {{type}}, overflow : Int32*) : {{type}}
    overflow.value = 0
    result = a &* b
    if a == {{type}}::MIN
      if b != 0 && b != 1
        overflow.value = 1
      end
      return result
    end
    if b == {{type}}::MIN
      if a != 0 && a != 1
        overflow.value = 1
      end
      return result
    end
    sa = a >> {{n - 1}}
    abs_a = (a ^ sa) &- sa
    sb = b >> {{n - 1}}
    abs_b = (b ^ sb) &- sb
    if abs_a < 2 || abs_b < 2
      return result
    end
    if sa == sb
      if abs_a > ({{type}}::MAX // abs_b)
        overflow.value = 1
      end
    else
      if abs_a > ({{type}}::MIN // ({{type}}.new(0) &- abs_b))
        overflow.value = 1
      end
    end
    return result
  end
end

__mul_impl(__mulosi4, Int32, 32)
__mul_impl(__mulodi4, Int64, 64)
__mul_impl(__muloti4, Int128, 128)

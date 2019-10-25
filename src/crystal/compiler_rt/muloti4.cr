# Functions for returning the product of signed multiplication with overflow eg. `a * b`
# Ported from compiler-rt:lib/builtins/muloti4.c

fun __muloti4(a : Int128, b : Int128, overflow : Int32*) : Int128
  n = sizeof(Int128) &* sizeof(Char)
  min = Int64::MIN
  max = Int64::MAX
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
    if abs_a > min // -abs_b
      overflow.value = 1
    end
  end

  result
end

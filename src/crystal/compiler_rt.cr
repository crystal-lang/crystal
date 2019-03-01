{% skip_file unless flag?(:compiler_rt) %}

fun __mulodi4(a : Int64, b : Int64, overflow : Int32*) : Int64
  n = 64
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
    if abs_a > max / abs_b
      overflow.value = 1
    end
  else
    if abs_a > min / (0_i64 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end

fun __multi3(a : Int128, b : Int128, overflow : Int32*) : Int128
  n = 128
  min = Int128::MIN
  max = Int128::MAX
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
    if abs_a > max / abs_b
      overflow.value = 1
    end
  else
    if abs_a > min / (0_i128 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end

fun __umulti3(a : Int128, b : Int128, overflow : Int32*) : Int128
  n = 128
  min = Int128::MIN
  max = Int128::MAX
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
    if abs_a > max / abs_b
      overflow.value = 1
    end
  else
    if abs_a > min / (0_i128 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end

fun __modti3(a : Int128, b : Int128, overflow : Int32*) : Int128
  n = 128
  min = Int128::MIN
  max = Int128::MAX
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
    if abs_a > max / abs_b
      overflow.value = 1
    end
  else
    if abs_a > min / (0_i128 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end

fun __umodti3(a : UInt128, b : UInt128, overflow : Int32*) : UInt128
  n = 128
  min = UInt128::MIN
  max = UInt128::MAX
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
    if abs_a > max / abs_b
      overflow.value = 1
    end
  else
    if abs_a > min / (0_i128 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end

fun __divti3(a : Int128, b : Int128, overflow : Int32*) : Int128
  n = 128
  min = Int128::MIN
  max = Int128::MAX
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
    if abs_a > max / abs_b
      overflow.value = 1
    end
  else
    if abs_a > min / (0_i128 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end

fun __udivti3(a : UInt128, b : UInt128, overflow : Int32*) : UInt128
  n = 128
  min = UInt128::MIN
  max = UInt128::MAX
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
    if abs_a > max / abs_b
      overflow.value = 1
    end
  else
    if abs_a > min / (0_i128 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end

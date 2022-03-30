# :nodoc:
# Ported from https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/lib/builtins/ashlti3.c
#
# Returns: a << b
# Precondition:  0 <= b < bits_in_tword
fun __ashlti3(a : Int128, b : Int32) : Int128
  low, high = a.unsafe_as(Tuple(UInt64, Int64))
  if b >= 64
    low, high = 0u64, low.unsafe_shl(b &- 64).to_i64!
  elsif b == 0
    return a
  else
    low, high = low.unsafe_shl(b), high.unsafe_shl(b) | low.unsafe_shr(64 &- b)
  end

  {low, high}.unsafe_as(Int128)
end

# :nodoc:
# Ported from https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/lib/builtins/ashrti3.c
#
# Returns: a >> b
# Precondition:  0 <= b < bits_in_tword
fun __ashrti3(a : Int128, b : Int32) : Int128
  low, high = a.unsafe_as(Tuple(UInt64, Int64))
  if b >= 64
    low, high = high.unsafe_shr(b &- 64), high.unsafe_shr(63)
  elsif b == 0
    return a
  else
    low, high = high.unsafe_shl(64 &- b) | low.unsafe_shr(b), high.unsafe_shr(b)
  end

  {low, high}.unsafe_as(Int128)
end

# :nodoc:
# Ported from https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/lib/builtins/lshrti3.c
#
# Returns: logical a >> b
# Precondition:  0 <= b < bits_in_tword
fun __lshrti3(a : Int128, b : Int32) : Int128
  low, high = a.unsafe_as(Tuple(UInt64, UInt64))
  if b >= 64
    low, high = high.unsafe_shr(b &- 64), 0u64
  elsif b == 0
    return a
  else
    low, high = high.unsafe_shl(64 &- b) | low.unsafe_shr(b), high.unsafe_shr(b)
  end

  {low, high}.unsafe_as(Int128)
end

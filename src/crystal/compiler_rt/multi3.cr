private def __mulddi3(a : UInt64, b : UInt64) : Int128
  bits_in_dword_2 = (sizeof(Int64) &* 8).unsafe_div(2)
  lower_mask = (~0_u64).unsafe_shr(bits_in_dword_2)

  low = (a & lower_mask) &* (b & lower_mask)
  t = low.unsafe_shr(bits_in_dword_2)
  low &= lower_mask
  t &+= a.unsafe_shr(bits_in_dword_2) &* (b & lower_mask)
  low &+= (t & lower_mask).unsafe_shl(bits_in_dword_2)
  high = t.unsafe_shr(bits_in_dword_2)
  t = low.unsafe_shr(bits_in_dword_2)
  low &= lower_mask
  t &+= b.unsafe_shr(bits_in_dword_2) &* (a & lower_mask)
  low &+= (t & lower_mask).unsafe_shl(bits_in_dword_2)
  high &+= t.unsafe_shr(bits_in_dword_2)
  high &+= a.unsafe_shr(bits_in_dword_2) &* b.unsafe_shr(bits_in_dword_2)

  high.to_i128!.unsafe_shl(64) &+ low
end

# :nodoc:
# Ported from https://github.com/llvm/llvm-project/blob/ce59ccd04023cab3a837da14079ca2dcbfebb70c/compiler-rt/lib/builtins/multi3.c
fun __multi3(a : Int128, b : Int128) : Int128
  a_low = (a & ~0_u64).to_u64!
  a_high = a.unsafe_shr(64).to_i64!
  b_low = (b & ~0_u64).to_u64!
  b_high = b.unsafe_shr(64).to_i64!

  result = __mulddi3(a_low, b_low)
  result &+= ((a_high &* b_low) &+ (a_low &* b_high)).to_i128!.unsafe_shl(64)
  result
end

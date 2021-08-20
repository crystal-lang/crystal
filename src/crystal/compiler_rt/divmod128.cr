# This file includes an implementation of (U)Int128 modulo/division operations on 32-bit systems.

# :nodoc:
fun __divti3(a : Int128, b : Int128) : Int128
  # Copied from compiler-rt

  s_a = a >> 127
  s_b = b >> 127
  a = (a ^ s_a) &- s_a
  b = (b ^ s_b) &- s_b
  s_a ^= s_b
  quo, _ = _u128_div_rem(a.to_u128!, b.to_u128!)
  ((quo ^ s_a) &- s_a).to_i128!
end

# :nodoc:
fun __modti3(a : Int128, b : Int128) : Int128
  # Copied from compiler-rt

  s = b >> 127
  b = (b ^ s) &- s
  s = a >> 127
  a = (a ^ s) &- s
  _, rem = _u128_div_rem(a.to_u128!, b.to_u128!)
  (rem.to_i128! ^ s) &- s
end

# :nodoc:
fun __udivti3(a : UInt128, b : UInt128) : UInt128
  # Copied from compiler-rt

  quo, _ = _u128_div_rem(a, b)
  quo
end

# :nodoc:
fun __umodti3(a : UInt128, b : UInt128) : UInt128
  # Copied from compiler-rt

  _, rem = _u128_div_rem(a, b)
  rem
end

# :nodoc:
def _carrying_mul(lhs : UInt64, rhs : UInt64) : Tuple(UInt64, UInt64)
  # Copied from rust-lang/compiler-builtins

  tmp = lhs.to_u128! &* rhs.to_u128!
  {tmp.to_u64!, (tmp >> 64).to_u64!}
end

# :nodoc:
def _carrying_mul_add(lhs : UInt64, mul : UInt64, add : UInt64) : Tuple(UInt64, UInt64)
  # Copied from rust-lang/compiler-builtins

  tmp = lhs.to_u128!
  tmp &*= mul.to_u128!
  tmp &+= add.to_u128!
  {tmp.to_u64!, (tmp >> 64).to_u64!}
end

# :nodoc:
def _u128_div_rem(duo : UInt128, div : UInt128) : Tuple(UInt128, UInt128)
  # Copied from rust-lang/compiler-builtins (trifecta algorithm)

  div_lz = div.leading_zeros_count
  duo_lz = duo.leading_zeros_count

  if div_lz <= duo_lz
    if duo >= div
      return {UInt128.new(1), duo - div}
    else
      return {UInt128.new(0), duo}
    end
  end

  if duo_lz >= 64
    quo_local1 = duo.to_u64! // div.to_u64!
    rem_local1 = duo.to_u64! % div.to_u64!
    return {quo_local1.to_u128!, rem_local1.to_u128!}
  end

  if div_lz >= 96
    duo_hi = (duo >> 64).to_u64!
    div_0 = div.to_u32!.to_u64!
    quo_hi = duo_hi // div_0
    rem_3 = duo_hi % div_0

    duo_mid = (duo >> 32).to_u32!.to_u64! | (rem_3 << 32)
    quo_1 = duo_mid // div_0
    rem_2 = duo_mid % div_0

    duo_lo = duo.to_u32!.to_u64! | (rem_2 << 32)
    quo_0 = duo_lo // div_0
    rem_1 = duo_lo % div_0

    return {quo_0.to_u128! | (quo_1.to_u128! << 32) | (quo_hi.to_u128! << 64), rem_1.to_u128!}
  end

  lz_diff = div_lz - duo_lz

  if lz_diff < 32
    shift = 64 - duo_lz
    duo_sig_n = (duo >> shift).to_u64!
    div_sig_n = (div >> shift).to_u64!
    quo_local2 = duo_sig_n // div_sig_n

    div_lo = div.to_u64!
    div_hi = (div >> 64).to_u64!
    tmp_lo, carry = _carrying_mul(quo_local2, div_lo)
    tmp_hi, overflow = _carrying_mul_add(quo_local2, div_hi, carry)
    tmp = tmp_lo.to_u128! | (tmp_hi.to_u128! << 64)
    if (overflow != 0) || (duo < tmp)
      return {(quo_local2 - 1).to_u128!, duo &+ div &- tmp}
    else
      return {quo_local2.to_u128!, duo - tmp}
    end
  end

  quo : UInt128 = 0
  div_extra = 96 - div_lz
  div_sig_n_h = (div >> div_extra).to_u32!
  div_sig_n_h_add1 = div_sig_n_h.to_u64! + 1

  loop do
    duo_extra = 64 - duo_lz
    duo_sig_n = (duo >> duo_extra).to_u64!

    if div_extra <= duo_extra
      quo_part = (duo_sig_n // div_sig_n_h_add1).to_u128!
      extra_shl = duo_extra - div_extra
      quo += (quo_part << extra_shl)
      duo -= ((div &* quo_part) << extra_shl)
    else
      shift = 64 - duo_lz
      duo_sig_n = (duo >> shift).to_u64!
      div_sig_n = (div >> shift).to_u64!
      quo_part = duo_sig_n // div_sig_n
      div_lo = div.to_u64!
      div_hi = (div >> 64).to_u64!

      tmp_lo, carry = _carrying_mul(quo_part, div_lo)
      tmp_hi, _ = _carrying_mul_add(quo_part, div_hi, carry)
      tmp = tmp_lo.to_u128! | (tmp_hi.to_u128! << 64)

      if duo < tmp
        return {quo + (quo_part - 1), duo &+ div &- tmp}
      else
        return {quo + quo_part, duo - tmp}
      end
    end

    duo_lz = duo.leading_zeros_count

    if div_lz <= duo_lz
      if div <= duo
        return {quo + 1, duo - div}
      else
        return {quo, duo}
      end
    end

    if 64 <= duo_lz
      quo_local3 = duo.to_u64! // div.to_u64!
      rem_local2 = duo.to_u64! % div.to_u64!
      return {quo_local3.to_u128! + quo_local3, rem_local2.to_u128!}
    end
  end
end

require "./ascii_number"
require "./decimal_to_binary"
require "./digit_comparison"
require "./float_common"

module Float::FastFloat
  module Detail
    def self.parse_infnan(first : UC*, last : UC*, value : T*) : FromCharsResultT(UC) forall T, UC
      ptr = first
      ec = Errno::NONE # be optimistic
      minus_sign = false
      if first.value === '-' # assume first < last, so dereference without checks
        minus_sign = true
        first += 1
      elsif first.value === '+'
        first += 1
      end

      if last - first >= 3
        if FastFloat.fastfloat_strncasecmp(first, "nan".to_unsafe, 3)
          first += 3
          ptr = first
          value.value = minus_sign ? -T::NAN : T::NAN
          # Check for possible nan(n-char-seq-opt), C++17 20.19.3.7,
          # C11 7.20.1.3.3. At least MSVC produces nan(ind) and nan(snan).
          if first != last && first.value === '('
            ptr2 = first + 1
            while ptr2 != last
              case ptr2.value.unsafe_chr
              when ')'
                ptr = ptr2 + 1 # valid nan(n-char-seq-opt)
                break
              when 'a'..'z', 'A'..'Z', '0'..'9', '_'
                # Do nothing
              else
                break # forbidden char, not nan(n-char-seq-opt)
              end
              ptr2 += 1
            end
          end
          return FromCharsResultT(UC).new(ptr, ec)
        end
      end
      if FastFloat.fastfloat_strncasecmp(first, "inf".to_unsafe, 3)
        if last - first >= 8 && FastFloat.fastfloat_strncasecmp(first + 3, "inity".to_unsafe, 5)
          ptr = first + 8
        else
          ptr = first + 3
        end
        value.value = minus_sign ? -T::INFINITY : T::INFINITY
        return FromCharsResultT(UC).new(ptr, ec)
      end

      ec = Errno::EINVAL
      FromCharsResultT(UC).new(ptr, ec)
    end

    # See
    # A fast function to check your floating-point rounding mode
    # https://lemire.me/blog/2022/11/16/a-fast-function-to-check-your-floating-point-rounding-mode/
    #
    # This function is meant to be equivalent to :
    # prior: #include <cfenv>
    #  return fegetround() == FE_TONEAREST;
    # However, it is expected to be much faster than the fegetround()
    # function call.
    #
    # NOTE(crystal): uses a pointer instead of a volatile variable to prevent
    # LLVM optimization
    @@fmin : Float32* = Pointer(Float32).malloc(1, Float32::MIN_POSITIVE)

    # Returns true if the floating-pointing rounding mode is to 'nearest'.
    # It is the default on most system. This function is meant to be inexpensive.
    # Credit : @mwalcott3
    def self.rounds_to_nearest? : Bool
      fmin = @@fmin.value # we copy it so that it gets loaded at most once.

      # Explanation:
      # Only when fegetround() == FE_TONEAREST do we have that
      # fmin + 1.0f == 1.0f - fmin.
      #
      # FE_UPWARD:
      #  fmin + 1.0f > 1
      #  1.0f - fmin == 1
      #
      # FE_DOWNWARD or  FE_TOWARDZERO:
      #  fmin + 1.0f == 1
      #  1.0f - fmin < 1
      #
      # Note: This may fail to be accurate if fast-math has been
      # enabled, as rounding conventions may not apply.
      fmin + 1.0_f32 == 1.0_f32 - fmin
    end
  end

  module BinaryFormat(T, EquivUint)
    def from_chars_advanced(pns : ParsedNumberStringT(UC), value : T*) : FromCharsResultT(UC) forall UC
      {% raise "only some floating-point types are supported" unless T == Float32 || T == Float64 %}

      # TODO(crystal): support UInt16 and UInt32
      {% raise "only UInt8 is supported" unless UC == UInt8 %}

      ec = Errno::NONE # be optimistic
      ptr = pns.lastmatch
      # The implementation of the Clinger's fast path is convoluted because
      # we want round-to-nearest in all cases, irrespective of the rounding mode
      # selected on the thread.
      # We proceed optimistically, assuming that detail::rounds_to_nearest()
      # returns true.
      if (min_exponent_fast_path <= pns.exponent <= max_exponent_fast_path) && !pns.too_many_digits
        # Unfortunately, the conventional Clinger's fast path is only possible
        # when the system rounds to the nearest float.
        #
        # We expect the next branch to almost always be selected.
        # We could check it first (before the previous branch), but
        # there might be performance advantages at having the check
        # be last.
        if Detail.rounds_to_nearest?
          # We have that fegetround() == FE_TONEAREST.
          # Next is Clinger's fast path.
          if pns.mantissa <= max_mantissa_fast_path
            if pns.mantissa == 0
              value.value = pns.negative ? T.new(-0.0) : T.new(0.0)
              return FromCharsResultT(UC).new(ptr, ec)
            end
            value.value = T.new(pns.mantissa)
            if pns.exponent < 0
              value.value /= exact_power_of_ten(0_i64 &- pns.exponent)
            else
              value.value *= exact_power_of_ten(pns.exponent)
            end
            if pns.negative
              value.value = -value.value
            end
            return FromCharsResultT(UC).new(ptr, ec)
          end
        else
          # We do not have that fegetround() == FE_TONEAREST.
          # Next is a modified Clinger's fast path, inspired by Jakub Jelínek's
          # proposal
          if pns.exponent >= 0 && pns.mantissa <= max_mantissa_fast_path(pns.exponent)
            # Clang may map 0 to -0.0 when fegetround() == FE_DOWNWARD
            if pns.mantissa == 0
              value.value = pns.negative ? T.new(-0.0) : T.new(0.0)
              return FromCharsResultT(UC).new(ptr, ec)
            end
            value.value = T.new(pns.mantissa) * exact_power_of_ten(pns.exponent)
            if pns.negative
              value.value = -value.value
            end
            return FromCharsResultT(UC).new(ptr, ec)
          end
        end
      end
      am = compute_float(pns.exponent, pns.mantissa)
      if pns.too_many_digits && am.power2 >= 0
        if am != compute_float(pns.exponent, pns.mantissa &+ 1)
          am = compute_error(pns.exponent, pns.mantissa)
        end
      end
      # If we called compute_float<binary_format<T>>(pns.exponent, pns.mantissa)
      # and we have an invalid power (am.power2 < 0), then we need to go the long
      # way around again. This is very uncommon.
      if am.power2 < 0
        am = digit_comp(pns, am)
      end
      value.value = to_float(pns.negative, am)
      # Test for over/underflow.
      if (pns.mantissa != 0 && am.mantissa == 0 && am.power2 == 0) || am.power2 == infinite_power
        ec = Errno::ERANGE
      end
      FromCharsResultT(UC).new(ptr, ec)
    end

    def from_chars_advanced(first : UC*, last : UC*, value : T*, options : ParseOptionsT(UC)) : FromCharsResultT(UC) forall UC
      {% raise "only some floating-point types are supported" unless T == Float32 || T == Float64 %}

      # TODO(crystal): support UInt16 and UInt32
      {% raise "only UInt8 is supported" unless UC == UInt8 %}

      if first == last
        return FromCharsResultT(UC).new(first, Errno::EINVAL)
      end
      pns = FastFloat.parse_number_string(first, last, options)
      if !pns.valid
        if options.format.no_infnan?
          return FromCharsResultT(UC).new(first, Errno::EINVAL)
        else
          return Detail.parse_infnan(first, last, value)
        end
      end

      # call overload that takes parsed_number_string_t directly.
      from_chars_advanced(pns, value)
    end
  end
end

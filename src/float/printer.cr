require "./printer/*"

# :nodoc:
module Float::Printer
  extend self

  BUFFER_SIZE = 17 # maximum number of decimal digits required

  # Writes *v*'s shortest string representation to the given *io*.
  #
  # Based on the [Dragonbox](https://github.com/jk-jeon/dragonbox) algorithm
  # developed by Junekey Jeon around 2020-2021.
  #
  # It is used by `Float::Primitive#to_s` and `Number#format`. It is probably
  # not necessary to use this directly.
  #
  # *point_range* designates the boundaries of scientific notation which is used
  # for all values whose decimal point position is outside that range.
  def shortest(v : Float::Primitive, io : IO, *, point_range = -3..15) : Nil
    check_finite_float(v, io) do |pos_v|
      if pos_v.zero?
        io << "0.0"
        return
      end

      significand, decimal_exponent = Dragonbox.to_decimal(pos_v)

      # remove trailing zeros
      while significand.unsafe_mod(10) == 0
        significand = significand.unsafe_div(10)
        decimal_exponent += 1
      end

      # generate `significand.to_s` in a reasonably fast manner
      str = uninitialized UInt8[BUFFER_SIZE]
      ptr = str.to_unsafe + BUFFER_SIZE
      while significand > 0
        ptr -= 1
        ptr.value = 48_u8 &+ significand.unsafe_mod(10).to_u8!
        significand = significand.unsafe_div(10)
      end

      buffer = str.to_slice[ptr - str.to_unsafe..]
      decimal(io, buffer, decimal_exponent, point_range, :write_all)
    end
  end

  # How to output the decimal part in `#decimal`.
  enum FractionMode
    # Writes the decimal separator and all digits that follow.
    # Also writes `.0` if the decimal part is empty.
    WriteAll

    # If there are two or more digits, removes all consecutive trailing zeros,
    # except that the digit past the decimal separator is always kept.
    # `.100` becomes `.1`, and `.00` becomes `.0`.
    # Also writes `.0` if the decimal part is empty.
    RemoveExtraZeros

    # If all the digits are zero, does not write the decimal separator nor the
    # digits. Otherwise writes everything.
    # `.100` becomes `.100`, and `.00` becomes the empty string.
    RemoveIfZero
  end

  # The general printing algorithm for decimal numbers. Writes to the given *io*
  # the value *digits*, interpreted as an ASCII numeric string, and then
  # multiplied by 10 to the *decimal_exponent*-th power.
  #
  # *digits* must not be empty or contain any leading zeros or minus signs. It
  # may however contain redundant trailing zeros.
  #
  # *point_range* designates the boundaries of scientific notation which is used
  # for all values whose decimal point position is outside that range. The
  # scientific notation can be unconditionally enabled or disabled by passing
  # `0...0` or `..` to this parameter.
  #
  # *fraction* determines if and how the decimal separator and the decimal part
  # are written. Refer to `FractionMode` for the options available.
  def decimal(io : IO, digits : Bytes, decimal_exponent : Int, point_range : Range, fraction : FractionMode) : Nil
    length = digits.size

    exp = decimal_exponent + length
    exp_mode = !point_range.includes?(exp)
    point = exp_mode ? 1 : exp

    # add integer part digits
    if decimal_exponent > 0 && !exp_mode
      # whole number but not big enough to be exp form
      io.write_string digits
      digits = Bytes.empty
      decimal_exponent.times { io << '0' }
    elsif point > 0
      io.write_string digits[0, point]
      digits = digits[point..]
    else
      # add leading zero
      io << '0'
    end

    unless fraction.remove_if_zero? && digits.all?(&.=== '0')
      io << '.'

      # add leading zeros after point
      (-point).times { io << '0' }

      # add fractional part digits
      digits = remove_extra_zeros(digits) if fraction.remove_extra_zeros?
      io.write_string(digits)

      # print trailing 0 if whole number or exp notation of power of ten
      io << '0' if digits.empty?
    end

    # exp notation
    if exp_mode
      io << 'e'
      io << '+' if exp > 0
      (exp - 1).to_s(io)
    end
  end

  private def remove_extra_zeros(digits : Bytes) : Bytes
    return digits if digits.empty?
    b = digits.to_unsafe
    e = b + digits.size - 1
    while e > b && e.value === '0'
      e -= 1
    end
    Slice.new(b, e + 1 - b)
  end

  # Writes *v*'s hexadecimal-significand representation to the given *io*.
  #
  # Used by `Float::Primitive#to_hexfloat` and `String::Formatter#float_hex`.
  def hexfloat(v : Float64, io : IO, **opts) : Nil
    check_finite_float(v, io) do
      Hexfloat(Float64, UInt64).to_s(io, v, **opts)
    end
  end

  # :ditto:
  def hexfloat(v : Float32, io : IO, **opts) : Nil
    check_finite_float(v, io) do
      Hexfloat(Float32, UInt32).to_s(io, v, **opts)
    end
  end

  # If *v* is finite, yields its absolute value, otherwise writes *v* to *io*.
  private def check_finite_float(v : Float::Primitive, io : IO, &)
    d = IEEE.to_uint(v)

    if IEEE.nan?(d)
      io << "NaN"
      return
    end

    if IEEE.sign(d) < 0
      io << '-'
      v = -v
    end

    if IEEE.inf?(d)
      io << "Infinity"
    else
      yield v
    end
  end
end

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

      # generate `significand.to_s` in a reasonably fast manner
      str = uninitialized UInt8[BUFFER_SIZE]
      ptr = str.to_unsafe + BUFFER_SIZE
      while significand > 0
        ptr -= 1
        ptr.value = 48_u8 &+ significand.unsafe_mod(10).to_u8!
        significand = significand.unsafe_div(10)
      end

      # remove trailing zeros
      buffer = str.to_slice[ptr - str.to_unsafe..]
      while buffer.size > 1 && buffer.unsafe_fetch(buffer.size - 1) === '0'
        buffer = buffer[..-2]
        decimal_exponent += 1
      end
      length = buffer.size

      point = decimal_exponent + length

      exp = point
      exp_mode = !point_range.includes?(point)
      point = 1 if exp_mode

      # add leading zero
      io << '0' if point < 1

      i = 0

      # add integer part digits
      if decimal_exponent > 0 && !exp_mode
        # whole number but not big enough to be exp form
        io.write_string buffer.to_slice[i, length - i]
        i = length
        (point - length).times { io << '0' }
      elsif i < point
        io.write_string buffer.to_slice[i, point - i]
        i = point
      end

      io << '.'

      # add leading zeros after point
      if point < 0
        (-point).times { io << '0' }
      end

      # add fractional part digits
      io.write_string buffer.to_slice[i, length - i]

      # print trailing 0 if whole number or exp notation of power of ten
      if (decimal_exponent >= 0 && !exp_mode) || (exp != point && length == 1)
        io << '0'
      end

      # exp notation
      if exp != point
        io << 'e'
        io << '+' if exp > 0
        (exp - 1).to_s(io)
      end
    end
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

require "./printer/*"

# :nodoc:
#
# `Float::Printer` is based on the [Dragonbox](https://github.com/jk-jeon/dragonbox)
# algorithm developed by Junekey Jeon around 2020-2021.
module Float::Printer
  extend self
  BUFFER_SIZE = 17 # maximum number of decimal digits required

  # Converts `Float` *v* to a string representation and prints it onto *io*.
  #
  # It is used by `Float64#to_s` and it is probably not necessary to use
  # this directly.
  def print(v : Float64 | Float32, io : IO) : Nil
    d = IEEE.to_uint(v)

    if IEEE.sign(d) < 0
      io << '-'
      v = -v
    end

    if v == 0.0
      io << "0.0"
    elsif IEEE.special?(d)
      if IEEE.inf?(d)
        io << "Infinity"
      else
        io << "NaN"
      end
    else
      internal(v, io)
    end
  end

  private def internal(v : Float64 | Float32, io : IO)
    significand, decimal_exponent = Dragonbox.to_decimal(v)

    # generate `significand.to_s` in a reasonable fast manner
    str = StaticArray(UInt8, BUFFER_SIZE).new(0_u8)
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
    exp_mode = point > 15 || point < -3
    point = 1 if exp_mode

    # add leading zero
    io << '0' if point < 1

    i = 0

    # add integer part digits
    if decimal_exponent > 0 && !exp_mode
      # whole number but not big enough to be exp form
      io.write_utf8 buffer.to_slice[i, length - i]
      i = length
      (point - length).times { io << '0' }
    elsif i < point
      io.write_utf8 buffer.to_slice[i, point - i]
      i = point
    end

    io << '.'

    # add leading zeros after point
    if point < 0
      (-point).times { io << '0' }
    end

    # add fractional part digits
    io.write_utf8 buffer.to_slice[i, length - i]
    i = length

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

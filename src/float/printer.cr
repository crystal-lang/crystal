require "./printer/*"

# Float::Printer is based on Grisu3 algorithm described in the 2004 paper
# "Printing Floating-Point Numbers Quickly and Accurately with Integers" by
# Florian Loitsch.
module Float::Printer
  extend self
  BUFFER_SIZE = 128

  # Converts Float *v* to a string representation and prints it onto *io*
  #
  # It is used by `Float64#to_s` and it is probably not necessary to use
  # this directly.
  def print(v : Float64 | Float32, io : IO)
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
    buffer = StaticArray(UInt8, BUFFER_SIZE).new(0_u8)
    success, decimal_exponent, length = Grisu3.grisu3(v, buffer.to_unsafe)

    unless success
      # grisu3 does not work for ~0.5% of floats
      # when this happens, fallback to another, slower approach
      if v.class == Float64
        LibC.snprintf(buffer.to_unsafe, BUFFER_SIZE, "%.17g", v)
      else
        LibC.snprintf(buffer.to_unsafe, BUFFER_SIZE, "%g", v)
      end
      len = LibC.strlen(buffer)
      io.write_utf8 buffer.to_slice[0, len]
      return
    end

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

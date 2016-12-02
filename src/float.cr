require "c/stdio"
require "c/string"

# Float is the base type of all floating point numbers.
#
# There are two floating point types, `Float32` and `Float64`,
# which correspond to the [binary32](http://en.wikipedia.org/wiki/Single_precision_floating-point_format)
# and [binary64](http://en.wikipedia.org/wiki/Double_precision_floating-point_format)
# types defined by IEEE.
#
# A floating point literal is an optional `+` or `-` sign, followed by
# a sequence of numbers or underscores, followed by a dot,
# followed by numbers or underscores, followed by an optional exponent suffix,
# followed by an optional type suffix. If no suffix is present, the literal's type is `Float64`.
#
# ```
# 1.0     # Float64
# 1.0_f32 # Float32
# 1_f32   # Float32
#
# 1e10   # Float64
# 1.5e10 # Float64
# 1.5e-7 # Float64
#
# +1.3 # Float64
# -0.5 # Float64
# ```
#
# The underscore `_` before the suffix is optional.
#
# Underscores can be used to make some numbers more readable:
#
# ```
# 1_000_000.111_111 # better than 1000000.111111
# ```
struct Float
  alias Primitive = Float32 | Float64

  def -
    self.class.zero - self
  end

  def %(other)
    modulo(other)
  end

  def nan?
    !(self == self)
  end

  def infinite?
    if nan? || self == 0 || self != 2 * self
      nil
    else
      self > 0 ? 1 : -1
    end
  end

  def finite?
    !nan? && !infinite?
  end

  def fdiv(other)
    self / other
  end

  def modulo(other)
    if other == 0.0
      raise DivisionByZero.new
    else
      self - other * self.fdiv(other).floor
    end
  end

  def remainder(other)
    if other == 0.0
      raise DivisionByZero.new
    else
      mod = self % other
      return self.class.zero if mod == 0.0
      return mod if self > 0 && other > 0
      return mod if self < 0 && other < 0

      mod - other
    end
  end

  # Writes this float to the given *io* in the given *format*.
  # See `IO#write_bytes`.
  def to_io(io : IO, format : IO::ByteFormat)
    format.encode(self, io)
  end

  # Reads a float from the given *io* in the given *format*.
  # See `IO#read_bytes`.
  def self.from_io(io : IO, format : IO::ByteFormat)
    format.decode(self, io)
  end
end

struct Float32
  NAN      = (0_f32 / 0_f32).as Float32
  INFINITY = (1_f32 / 0_f32).as Float32
  MIN      = (-INFINITY).as Float32
  MAX      = INFINITY.as Float32

  # Returns a `Float32` by invoking `to_f32` on *value*.
  def self.new(value)
    value.to_f32
  end

  def ceil
    LibM.ceil_f32(self)
  end

  def floor
    LibM.floor_f32(self)
  end

  def round
    LibM.round_f32(self)
  end

  def trunc
    LibM.trunc_f32(self)
  end

  def **(other : Int32)
    LibM.powi_f32(self, other)
  end

  def **(other : Float32)
    LibM.pow_f32(self, other)
  end

  def **(other)
    self ** other.to_f32
  end

  def to_s
    String.new(22) do |buffer|
      len = to_s_internal(buffer)
      {len, len}
    end
  end

  def to_s(io : IO)
    chars = StaticArray(UInt8, 22).new(0_u8)
    len = to_s_internal(chars.to_unsafe)
    io.write_utf8 chars.to_slice[0, len]
  end

  private def to_s_internal(buffer)
    LibC.snprintf(buffer, 22, "%g", to_f64)
    len = LibC.strlen(buffer)

    # If it's "inf", return "Infinity"
    if buffer[0] === 'i'
      buffer.copy_from("Infinity".to_unsafe, 8)
      len = 8
      return len
    end

    # If it's "-inf", return "-inf"
    if len >= 2 && buffer[1] === 'i'
      buffer.copy_from("-Infinity".to_unsafe, 9)
      len = 9
      return len
    end

    len
  end

  def hash
    n = self
    pointerof(n).as(Int32*).value
  end

  def clone
    self
  end
end

struct Float64
  NAN      = (0_f64 / 0_f64).as Float64
  INFINITY = (1_f64 / 0_f64).as Float64
  MIN      = (-INFINITY).as Float64
  MAX      = INFINITY.as Float64

  # Returns a `Float64` by invoking `to_f64` on *value*.
  def Float64.new(value)
    value.to_f64
  end

  def ceil
    LibM.ceil_f64(self)
  end

  def floor
    LibM.floor_f64(self)
  end

  def round
    LibM.round_f64(self)
  end

  def trunc
    LibM.trunc_f64(self)
  end

  def **(other : Int32)
    LibM.powi_f64(self, other)
  end

  def **(other : Float64)
    LibM.pow_f64(self, other)
  end

  def **(other)
    self ** other.to_f64
  end

  def to_s
    String.new(28) do |buffer|
      len = to_s_internal(buffer)
      {len, len}
    end
  end

  def to_s(io : IO)
    chars = StaticArray(UInt8, 28).new(0_u8)
    len = to_s_internal(chars.to_unsafe)
    io.write_utf8 chars.to_slice[0, len]
  end

  private def to_s_internal(buffer)
    LibC.snprintf(buffer, 28, "%.17g", self)
    len = LibC.strlen(buffer)
    slice = Slice.new(buffer, len)

    # If it's "inf", return "Infinity"
    if buffer[0] === 'i'
      buffer.copy_from("Infinity".to_unsafe, 8)
      len = 8
      return len
    end

    # If it's "-inf", return "-inf"
    if len >= 2 && buffer[1] === 'i'
      buffer.copy_from("-Infinity".to_unsafe, 9)
      len = 9
      return len
    end

    # Check if we have a run of zeros or nines after
    # the decimal digit. If so, we remove them
    # (rounding, if needed). This is a very simple
    # (and probably inefficient) algorithm, but a good
    # one is much longer and harder to do: we can probably
    # do that later.
    dot_index = slice.index('.'.ord.to_u8)

    # If there's no dot add ".0" to it
    unless dot_index
      # Check if we have an 'e'
      e_index = slice.index('e'.ord.to_u8)

      # If there's an "e", we must move it to the right
      if e_index
        (buffer + e_index).move_to(buffer + e_index + 2, len - e_index)
        buffer[e_index] = '.'.ord.to_u8
        buffer[e_index + 1] = '0'.ord.to_u8
      else
        buffer[len] = '.'.ord.to_u8
        buffer[len + 1] = '0'.ord.to_u8
      end
      len += 2
      return len
    end

    original_len = len
    index = dot_index

    # Also return if the dot is the last char (shouldn't happen)
    return len if index + 1 == len

    # And also return if the length is less than 7
    # (digit, dot plus at least 5 digits)
    return len if len < 7

    this_run = 0        # number of chars in this run
    max_run = 0         # maximum consecutive chars of a run
    run_byte = 0_u8     # the run character
    last_run_start = -1 # where did the last run start
    max_run_byte = 0_u8 # the byte of the last run
    max_run_start = -1  # the index where the maximum run starts
    max_run_end = -1    # the index where the maximum run ends
    e_index = nil

    while index < len
      byte = slice.to_unsafe[index]

      if byte == run_byte
        this_run += 1
        if this_run >= max_run
          max_run = this_run
          max_run_byte = byte
          max_run_start = last_run_start
          max_run_end = index
        end
      elsif byte === '0' || byte === '9'
        run_byte = byte
        last_run_byte = byte
        last_run_start = index
        this_run = 1
        if this_run >= max_run
          max_run = this_run
          max_run_byte = byte
          max_run_start = index
          max_run_end = index
        end
      elsif byte === 'e'
        e_index = index
        break
      else
        run_byte = 0_u8
        this_run = 0
      end

      index += 1
    end

    if e_index
      # If we have an 'e', remove a sequence of 0s or 9s or
      # any length, as long as they are near the end
      tolerance = 1
    else
      # The more digits we have to the left of the dot,
      # the less run digits we adjust
      tolerance = case dot_index
                  when 0..8  then 5
                  when 9..11 then 4
                  when    12 then 3
                  when    13 then 2
                  else            1
                  end
    end

    if e_index
      len = e_index
    end

    # If the maximum run ends one or two chars before
    # the end of the string, we replace the run
    if (len - 3 <= max_run_end < len) && max_run >= tolerance
      case max_run_byte
      when '0'
        # Just trim
        len = max_run_start
      when '9'
        # Need to add one and carry to the left
        len = max_run_start
        index = len - 1
        while index >= 0
          byte = slice.to_unsafe[index]
          case byte
          when '.'
            # Nothing, continue
          when '9'
            # If this is the last char, remove it,
            # otherwise turn into a zero
            if index == len
              len -= 1
            else
              slice.to_unsafe[index] = '0'.ord.to_u8
            end
          else
            slice.to_unsafe[index] = byte + 1
            break
          end
          index -= 1
        end
      end
    end

    # Add a zero if the last char is a dot
    if slice.to_unsafe[len - 1] === '.'
      slice.to_unsafe[len] = '0'.ord.to_u8
      len += 1
    end

    # Add back the e and what's to the right of it
    if e_index
      e_len = original_len - e_index
      (buffer + e_index).move_to(buffer + len, e_len)
      len += e_len
    end

    len
  end

  def hash
    n = self
    pointerof(n).as(Int64*).value
  end

  def clone
    self
  end
end

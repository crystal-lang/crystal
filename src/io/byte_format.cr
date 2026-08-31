# Defines a byte format to encode integers and floats
# from/to `Bytes` and `IO`.
#
# ### Decode from bytes
#
# ```
# bytes = Bytes[0x34, 0x12]
# int16 = IO::ByteFormat::LittleEndian.decode(Int16, bytes)
# int16 # => 0x1234_i16
# ```
#
# ### Decode from an IO
#
# ```
# io = IO::Memory.new(Bytes[0x34, 0x12])
# int16 = io.read_bytes(Int16, IO::ByteFormat::LittleEndian)
# int16 # => 0x1234_i16
# ```
#
# ### Encode to bytes
#
# ```
# raw = uninitialized UInt8[2]
# IO::ByteFormat::LittleEndian.encode(0x1234_i16, raw.to_slice)
# raw # => StaticArray[0x34, 0x12]
# ```
#
# ### Encode to IO
#
# ```
# io = IO::Memory.new
# io.write_bytes(0x1234_i16, IO::ByteFormat::LittleEndian)
# io.to_slice # => Bytes[0x34, 0x12]
# ```
module IO::ByteFormat
  abstract def encode(int : Int8, io : IO)
  abstract def encode(int : UInt8, io : IO)
  abstract def encode(int : Int16, io : IO)
  abstract def encode(int : UInt16, io : IO)
  abstract def encode(int : Int32, io : IO)
  abstract def encode(int : UInt32, io : IO)
  abstract def encode(int : Int64, io : IO)
  abstract def encode(int : UInt64, io : IO)
  abstract def encode(int : Int128, io : IO)
  abstract def encode(int : UInt128, io : IO)

  abstract def encode(int : Int8, bytes : Bytes)
  abstract def encode(int : UInt8, bytes : Bytes)
  abstract def encode(int : Int16, bytes : Bytes)
  abstract def encode(int : UInt16, bytes : Bytes)
  abstract def encode(int : Int32, bytes : Bytes)
  abstract def encode(int : UInt32, bytes : Bytes)
  abstract def encode(int : Int64, bytes : Bytes)
  abstract def encode(int : UInt64, bytes : Bytes)
  abstract def encode(int : Int128, bytes : Bytes)
  abstract def encode(int : UInt128, bytes : Bytes)

  abstract def decode(int : Int8.class, io : IO)
  abstract def decode(int : UInt8.class, io : IO)
  abstract def decode(int : Int16.class, io : IO)
  abstract def decode(int : UInt16.class, io : IO)
  abstract def decode(int : Int32.class, io : IO)
  abstract def decode(int : UInt32.class, io : IO)
  abstract def decode(int : Int64.class, io : IO)
  abstract def decode(int : UInt64.class, io : IO)
  abstract def decode(int : Int128.class, io : IO)
  abstract def decode(int : UInt128.class, io : IO)

  abstract def decode(int : Int8.class, bytes : Bytes)
  abstract def decode(int : UInt8.class, bytes : Bytes)
  abstract def decode(int : Int16.class, bytes : Bytes)
  abstract def decode(int : UInt16.class, bytes : Bytes)
  abstract def decode(int : Int32.class, bytes : Bytes)
  abstract def decode(int : UInt32.class, bytes : Bytes)
  abstract def decode(int : Int64.class, bytes : Bytes)
  abstract def decode(int : UInt64.class, bytes : Bytes)
  abstract def decode(int : Int128.class, bytes : Bytes)
  abstract def decode(int : UInt128.class, bytes : Bytes)

  def encode(float : Float32, io : IO) : Nil
    encode(float.unsafe_as(Int32), io)
  end

  def encode(float : Float32, bytes : Bytes)
    encode(float.unsafe_as(Int32), bytes)
  end

  def decode(type : Float32.class, io : IO) : Float32
    decode(Int32, io).unsafe_as(Float32)
  end

  def decode(type : Float32.class, bytes : Bytes) : Float32
    decode(Int32, bytes).unsafe_as(Float32)
  end

  def encode(float : Float64, io : IO) : Nil
    encode(float.unsafe_as(Int64), io)
  end

  def encode(float : Float64, bytes : Bytes)
    encode(float.unsafe_as(Int64), bytes)
  end

  def decode(type : Float64.class, io : IO) : Float64
    decode(Int64, io).unsafe_as(Float64)
  end

  def decode(type : Float64.class, bytes : Bytes) : Float64
    decode(Int64, bytes).unsafe_as(Float64)
  end

  module LittleEndian
    extend ByteFormat
  end

  module BigEndian
    extend ByteFormat
  end

  alias SystemEndian = LittleEndian
  alias NetworkEndian = BigEndian

  {% for mod in %w(LittleEndian BigEndian) %}
    module {{ mod.id }}
      {% for type, i in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64 Int128 UInt128) %}
        {% bytesize = 2 ** (i // 2) %}

        def self.encode(int : {{ type.id }}, io : IO)
          buffer = int.unsafe_as(StaticArray(UInt8, {{ bytesize }}))
          buffer.reverse! unless SystemEndian == self
          io.write(buffer.to_slice)
        end

        def self.encode(int : {{ type.id }}, bytes : Bytes)
          buffer = int.unsafe_as(StaticArray(UInt8, {{ bytesize }}))
          buffer.reverse! unless SystemEndian == self
          buffer.to_slice.copy_to(bytes)
        end

        def self.decode(int : {{ type.id }}.class, io : IO)
          buffer = uninitialized UInt8[{{ bytesize }}]
          io.read_fully(buffer.to_slice)
          buffer.reverse! unless SystemEndian == self
          buffer.unsafe_as({{ type.id }})
        end

        def self.decode(int : {{ type.id }}.class, bytes : Bytes)
          buffer = uninitialized UInt8[{{ bytesize }}]
          bytes.copy_to(buffer.to_unsafe, {{ bytesize }})
          buffer.reverse! unless SystemEndian == self
          buffer.unsafe_as({{ type.id }})
        end

        @[Deprecated("Use `.decode(int : {{ type.id }}.class, io : IO)` instead")]
        def self.decode(*, type : {{ type.id }}.class, io : IO)
          decode(type, io)
        end

        @[Deprecated("Use `.decode(int : {{ type.id }}.class, bytes : Bytes)` instead")]
        def self.decode(*, type : {{ type.id }}.class, bytes : Bytes)
          decode(type, bytes)
        end
      {% end %}
    end
  {% end %}
end

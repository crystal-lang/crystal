# Defines a byte format to encode integers and floats.
module IO::ByteFormat
  abstract def encode(int : Int8, io : IO)
  abstract def encode(int : UInt8, io : IO)
  abstract def encode(int : Int16, io : IO)
  abstract def encode(int : UInt16, io : IO)
  abstract def encode(int : Int32, io : IO)
  abstract def encode(int : UInt32, io : IO)
  abstract def encode(int : Int64, io : IO)
  abstract def encode(int : UInt64, io : IO)
  abstract def encode(int : Float32, io : IO)
  abstract def encode(int : Float64, io : IO)

  abstract def decode(int : Int8.class, io : IO)
  abstract def decode(int : UInt8.class, io : IO)
  abstract def decode(int : Int16.class, io : IO)
  abstract def decode(int : UInt16.class, io : IO)
  abstract def decode(int : Int32.class, io : IO)
  abstract def decode(int : UInt32.class, io : IO)
  abstract def decode(int : Int64.class, io : IO)
  abstract def decode(int : UInt64.class, io : IO)
  abstract def decode(int : Float32.class, io : IO)
  abstract def decode(int : Float64.class, io : IO)

  def encode(float : Float32, io : IO)
    encode(pointerof(float).as(Int32*).value, io)
  end

  def decode(type : Float32.class, io : IO)
    int = decode(Int32, io)
    pointerof(int).as(Float32*).value
  end

  def encode(float : Float64, io : IO)
    encode(pointerof(float).as(Int64*).value, io)
  end

  def decode(type : Float64.class, io : IO)
    int = decode(Int64, io)
    pointerof(int).as(Float64*).value
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
    module {{mod.id}}
      {% for type, i in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64) %}
        def self.encode(int : {{type.id}}, io : IO)
          buffer = pointerof(int).as(UInt8[{{2 ** (i / 2)}}]*).value
          buffer.reverse! unless SystemEndian == self
          io.write(buffer.to_slice)
        end

        def self.decode(type : {{type.id}}.class, io : IO)
          buffer = uninitialized UInt8[{{2 ** (i / 2)}}]
          io.read_fully(buffer.to_slice)
          buffer.reverse! unless SystemEndian == self
          buffer.to_unsafe.as(Pointer({{type.id}})).value
        end
      {% end %}
    end
  {% end %}
end

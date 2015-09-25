module IO::ByteFormat
  abstract def encode(int : Int::Primitive, io : IO)
  abstract def decode(int : Int::Primitive.class, io : IO)
  abstract def encode(int : Float::Primitive, io : IO)
  abstract def decode(int : Float::Primitive.class, io : IO)

  def encode(float : Float32, io : IO)
    encode((pointerof(float) as Int32*).value, io)
  end

  def encode(float : Float64, io : IO)
    encode((pointerof(float) as Int64*).value, io)
  end

  module LittleEndian
    extend ByteFormat

    {% for type in %w(Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64) %}
      def self.encode(int : {{type.id}}, io : IO)
        sizeof(typeof(int)).times do |i|
          io.write_byte((int & 0xFF).to_u8)
          int >>= 8
        end
      end
    {% end %}
  end

  module BigEndian
    extend ByteFormat

    {% for type in %w(Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64) %}
      def self.encode(int : {{type.id}}, io : IO)
        sizeof(typeof(int)).times do |i|
          shift = 8 * (sizeof(typeof(int)) - i - 1)
          io.write_byte(((int & (typeof(int).new(0xFF) << shift)) >> shift).to_u8)
        end
      end
    {% end %}
  end

  alias SystemEndian = LittleEndian
end

class HTTP::WebSocket
  OPCODE_CONT   = 0x0_u8
  OPCODE_TEXT   = 0x1_u8
  OPCODE_BINARY = 0x2_u8
  OPCODE_CLOSE  = 0x8_u8
  OPCODE_PING   = 0x9_u8
  OPCODE_PONG   = 0xa_u8

  MASK_BIT      = 128_u8

  struct PacketInfo
    property type
    property length
    property? final

    def initialize(type, @length, @final)
      @type = case type
      when OPCODE_TEXT then :text
      when OPCODE_BINARY then :binary
      when OPCODE_PING then :ping
      when OPCODE_PONG then :pong
      when OPCODE_CLOSE then :close
      else
        raise "Invalid packet type"
      end
    end
  end

  def initialize(@io)
    @header :: UInt8[2]
    @mask :: UInt8[4]
    @mask_offset = 0
    @type = OPCODE_CONT
    @remaining = 0
  end

  def send(data)
    write_header(data.length)
    @io.print data
    @io.flush
  end

  def send_masked(data)
    write_header(data.length, true)

    mask_array = StaticArray(UInt8, 4).new { rand(256).to_u8 }
    @io.write mask_array.to_slice

    data.length.times do |index|
      mask = mask_array[index % 4]
      @io.write_byte (mask ^ data.byte_at(index).to_u8).to_u8
    end
    @io.flush
  end

  private def write_header(length, masked = false)
    @io.write_byte(0x81_u8)

    mask = masked ? MASK_BIT : 0
    if length <= 125
      @io.write_byte(length.to_u8 | mask)
    elsif length <= UInt16::MAX
      @io.write_byte(126_u8 | mask)
      1.downto(0) { |i| @io.write_byte((length >> i * 8).to_u8) }
    else
      @io.write_byte(127_u8 | mask)
      3.downto(0) { |i| @io.write_byte((length >> i * 8).to_u8) }
    end
  end

  def receive(buffer : Slice(UInt8))
    if @remaining == 0
      # First byte: FIN (1 bit), RSV1,2,3 (3 bits), Opcode (4 bits)
      # Second byte: MASK (1 bit), Payload Length (7 bits)
      @io.read_fully(@header.to_slice)

      type = if continuation?
        @type
      elsif control?
        opcode
      else
        @type = opcode
      end

      length = (@header[1] & 0x7f_u8).to_i
      if length == 126
        length = 0
        2.times { length <<= 8; length += @io.read_byte.not_nil! }
      elsif length == 127
        length = 0
        4.times { length <<= 8; length += @io.read_byte.not_nil! }
      end

      @remaining = length

      # Read mask, if needed
      if masked?
        @io.read_fully(@mask.to_slice)
        @mask_offset = 0
      end
    else
      type = @type
    end

    read = @io.read buffer[0, Math.min(@remaining, buffer.length)]
    @remaining -= read

    # Unmask payload, if needed
    if masked?
      read.times do |i|
        buffer[i] ^= @mask[@mask_offset % 4]
        @mask_offset += 1
      end
    end

    PacketInfo.new(type, read.to_i, final? && @remaining == 0)
  end

  private def opcode
    @header[0] & 0x0f_u8
  end

  private def control?
    (@header[0] & 0x08_u8) != 0_u8
  end

  private def continuation?
    opcode == OPCODE_CONT
  end

  private def final?
    (@header[0] & 0x80_u8) != 0_u8
  end

  private def masked?
    (@header[1] & 0x80_u8) != 0_u8
  end

  def close
  end
end

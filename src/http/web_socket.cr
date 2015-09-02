class HTTP::WebSocket
  enum Opcode : UInt8
    CONTINUATION   = 0x0
    TEXT           = 0x1
    BINARY         = 0x2
    CLOSE          = 0x8
    PING           = 0x9
    PONG           = 0xA
  end

  MASK_BIT      = 128_u8

  record PacketInfo, opcode, length, final

  def initialize(@io)
    @header :: UInt8[2]
    @mask :: UInt8[4]
    @mask_offset = 0
    @opcode = Opcode::CONTINUATION
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
      opcode = read_header
    else
      opcode = @opcode
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

    PacketInfo.new(opcode, read.to_i, final? && @remaining == 0)
  end

  private def read_header
    # First byte: FIN (1 bit), RSV1,2,3 (3 bits), Opcode (4 bits)
    # Second byte: MASK (1 bit), Payload Length (7 bits)
    @io.read_fully(@header.to_slice)

    opcode = read_opcode
    @remaining = read_length

    # Read mask, if needed
    if masked?
      @io.read_fully(@mask.to_slice)
      @mask_offset = 0
    end

    opcode
  end

  private def read_opcode
    raw_opcode = @header[0] & 0x0f_u8
    parsed_opcode = Opcode.from_value(raw_opcode)
    unless parsed_opcode
      raise "Invalid packet opcode: #{raw_opcode}"
    end

    if parsed_opcode == Opcode::CONTINUATION
       @opcode
     elsif control?
       parsed_opcode
     else
       @opcode = parsed_opcode
     end
  end

  private def read_length
    length = (@header[1] & 0x7f_u8).to_i
    if length == 126
      length = 0
      2.times { length <<= 8; length += @io.read_byte.not_nil! }
    elsif length == 127
      length = 0
      4.times { length <<= 8; length += @io.read_byte.not_nil! }
    end
    length
  end

  private def control?
    (@header[0] & 0x08_u8) != 0_u8
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

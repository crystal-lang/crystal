require "socket"
require "http"
require "base64"
require "openssl" ifdef !without_openssl
require "uri"

# :nodoc:
class HTTP::WebSocket::Protocol
  @[Flags]
  enum Flags : UInt8
    FINAL = 0x80
    RSV1  = 0x40
    RSV2  = 0x20
    RSV3  = 0x10
  end

  enum Opcode : UInt8
    CONTINUATION = 0x0
    TEXT         = 0x1
    BINARY       = 0x2
    CLOSE        = 0x8
    PING         = 0x9
    PONG         = 0xA
  end

  MASK_BIT = 128_u8
  VERSION  =     13

  record PacketInfo,
    opcode : Opcode,
    size : Int32,
    final : Bool

  @io : IO
  @header : UInt8[2]
  @mask : UInt8[4]
  @remaining : Int32
  @mask_offset : Int32
  @opcode : Opcode
  @masked : Bool

  def initialize(@io : IO, @masked = false)
    @header = uninitialized UInt8[2]
    @mask = uninitialized UInt8[4]
    @mask_offset = 0
    @opcode = Opcode::CONTINUATION
    @remaining = 0
  end

  class StreamIO
    include IO

    @websocket : Protocol
    @buffer : Slice(UInt8)
    @pos : Int32
    @opcode : Opcode

    def initialize(@websocket, binary, frame_size)
      @opcode = binary ? Opcode::BINARY : Opcode::TEXT
      @buffer = Slice(UInt8).new(frame_size)
      @pos = 0
    end

    def write(slice : Slice(UInt8))
      count = Math.min(@buffer.size - @pos, slice.size)
      (@buffer + @pos).copy_from(slice.pointer(count), count)
      @pos += count

      if @pos == @buffer.size
        flush(final: false)
      end

      if count < slice.size
        write(slice + count)
      end

      nil
    end

    def read(slice : Slice(UInt8))
      raise "this IO is write-only"
    end

    def flush(final = true)
      @websocket.send(
        @buffer + (@pos % @buffer.size),
        @opcode,
        flags: final ? Flags::FINAL : Flags::None,
        flush: final
      )
      @opcode = Opcode::CONTINUATION
      @pos = 0
    end
  end

  def send(data : String)
    send(data.to_slice, Opcode::TEXT)
  end

  def send(data : Slice(UInt8))
    send(data, Opcode::BINARY)
  end

  def stream(binary = true, frame_size = 1024)
    stream_io = StreamIO.new(self, binary, frame_size)
    yield(stream_io)
    stream_io.flush
  end

  def send(data : Slice(UInt8), opcode : Opcode, flags = Flags::FINAL, flush = true)
    write_header(data.size, opcode, flags)
    write_payload(data)
    @io.flush if flush
  end

  def receive(buffer : Slice(UInt8))
    if @remaining == 0
      opcode = read_header
    else
      opcode = @opcode
    end

    read = read_payload(buffer)
    @remaining -= read
    PacketInfo.new(opcode, read.to_i, final? && @remaining == 0)
  end

  private def write_header(size, opcode, flags)
    @io.write_byte(flags.value | opcode.value)

    mask = @masked ? MASK_BIT : 0_u8
    if size <= 125
      @io.write_byte(size.to_u8 | mask)
    elsif size <= UInt16::MAX
      @io.write_byte(126_u8 | mask)
      @io.write_bytes(size.to_u16, IO::ByteFormat::NetworkEndian)
    else
      @io.write_byte(127_u8 | mask)
      @io.write_bytes(size.to_u64, IO::ByteFormat::NetworkEndian)
    end
  end

  private def write_payload(data)
    return @io.write(data) unless @masked

    key = Random::DEFAULT.next_int
    mask_array = (pointerof(key) as Pointer(UInt8[4])).value
    @io.write mask_array.to_slice

    data.each_with_index do |byte, index|
      mask = mask_array[index % 4]
      @io.write_byte(byte ^ mask_array[index % 4])
    end
  end

  private def read_header
    # First byte: FIN (1 bit), RSV1,2,3 (3 bits), Opcode (4 bits)
    # Second byte: MASK (1 bit), Payload Length (7 bits)
    @io.read_fully(@header.to_slice)

    opcode = read_opcode
    @remaining = read_size

    # Read mask, if needed
    if masked?
      @io.read_fully(@mask.to_slice)
      @mask_offset = 0
    end

    opcode
  end

  private def read_opcode
    raw_opcode = @header[0] & 0x0f_u8
    parsed_opcode = Opcode.from_value?(raw_opcode)
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

  private def read_size
    size = (@header[1] & 0x7f_u8).to_i
    if size == 126
      size = 0
      2.times { size <<= 8; size += @io.read_byte.not_nil! }
    elsif size == 127
      size = 0
      4.times { size <<= 8; size += @io.read_byte.not_nil! }
    end
    size
  end

  private def read_payload(buffer)
    count = Math.min(@remaining, buffer.size)
    @io.read_fully(buffer[0, count])
    if masked?
      count.times do |i|
        buffer[i] ^= @mask[@mask_offset % 4]
        @mask_offset += 1
      end
    end

    count
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

  def close(message = nil)
    if message
      send(message.to_slice, Opcode::CLOSE)
    else
      send(Slice.new(Pointer(UInt8).null, 0), Opcode::CLOSE)
    end
  end

  def self.new(host : String, path : String, port = nil, ssl = false)
    ifdef without_openssl
      if ssl
        raise "WebSocket ssl is disabled because `-D without_openssl` was passed at compile time"
      end
    end

    port = port || (ssl ? 443 : 80)

    socket = TCPSocket.new(host, port)

    ifdef !without_openssl
      socket = OpenSSL::SSL::Socket.new(socket, sync_close: true) if ssl
    end

    headers = HTTP::Headers.new
    headers["Host"] = "#{host}:#{port}"
    headers["Connection"] = "Upgrade"
    headers["Upgrade"] = "websocket"
    headers["Sec-WebSocket-Version"] = VERSION.to_s
    headers["Sec-WebSocket-Key"] = Base64.strict_encode(StaticArray(UInt8, 16).new { rand(256).to_u8 })

    path = "/" if path.empty?
    handshake = HTTP::Request.new("GET", path, headers)
    handshake.to_io(socket)
    handshake_response = HTTP::Client::Response.from_io(socket)
    unless handshake_response.status_code == 101
      raise Socket::Error.new("Handshake got denied. Status code was #{handshake_response.status_code}")
    end

    new(socket, masked: true)
  end

  def self.new(uri : URI | String)
    uri = URI.parse(uri) if uri.is_a?(String)

    if (host = uri.host) && (path = uri.path)
      ssl = uri.scheme == "https" || uri.scheme == "wss"
      return new(host, path, uri.port, ssl)
    end

    raise ArgumentError.new("No host or path specified which are required.")
  end
end

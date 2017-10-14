require "socket"
require "http"
require "base64"
{% if !flag?(:without_openssl) %}
  require "openssl"
{% end %}
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

  def initialize(@io : IO, masked = false)
    @header = uninitialized UInt8[2]
    @mask = uninitialized UInt8[4]
    @mask_offset = 0
    @opcode = Opcode::CONTINUATION
    @remaining = 0_u64
    @masked = !!masked
  end

  class StreamIO < IO
    def initialize(@websocket : Protocol, binary, frame_size)
      @opcode = binary ? Opcode::BINARY : Opcode::TEXT
      @buffer = Bytes.new(frame_size)
      @pos = 0
    end

    def write(slice : Bytes)
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

    def read(slice : Bytes)
      raise "This IO is write-only"
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

  def send(data : Bytes)
    send(data, Opcode::BINARY)
  end

  def stream(binary = true, frame_size = 1024)
    stream_io = StreamIO.new(self, binary, frame_size)
    yield(stream_io)
    stream_io.flush
  end

  def send(data : Bytes, opcode : Opcode, flags = Flags::FINAL, flush = true)
    write_header(data.size, opcode, flags)
    write_payload(data)
    @io.flush if flush
  end

  def receive(buffer : Bytes)
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
    mask_array = key.unsafe_as(StaticArray(UInt8, 4))
    @io.write mask_array.to_slice

    data.each_with_index do |byte, index|
      mask = mask_array[index & 0b11] # x & 0b11 == x % 4
      @io.write_byte(byte ^ mask_array[index & 0b11])
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
    size = (@header[1] & 0x7f_u8).to_u64
    if size == 126
      size = 0_u64
      2.times { size <<= 8; size += @io.read_byte.not_nil! }
    elsif size == 127
      size = 0_u64
      8.times { size <<= 8; size += @io.read_byte.not_nil! }
    end
    size
  end

  private def read_payload(buffer)
    count = Math.min(@remaining, buffer.size)
    @io.read_fully(buffer[0, count])
    if masked?
      count.times do |i|
        buffer[i] ^= @mask[@mask_offset & 0b11] # x & 0b11 == x % 4
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

  def ping(message = nil)
    if message
      send(message.to_slice, Opcode::PING)
    else
      send(Bytes.empty, Opcode::PING)
    end
  end

  def pong(message = nil)
    if message
      send(message.to_slice, Opcode::PONG)
    else
      send(Bytes.empty, Opcode::PONG)
    end
  end

  def close(message = nil)
    if message
      send(message.to_slice, Opcode::CLOSE)
    else
      send(Bytes.empty, Opcode::CLOSE)
    end
  end

  def self.new(host : String, path : String, port = nil, tls = false, headers = HTTP::Headers.new)
    {% if flag?(:without_openssl) %}
      if tls
        raise "WebSocket TLS is disabled because `-D without_openssl` was passed at compile time"
      end
    {% end %}

    port = port || (tls ? 443 : 80)

    socket = TCPSocket.new(host, port)

    {% if !flag?(:without_openssl) %}
      if tls
        if tls.is_a?(Bool) # true, but we want to get rid of the union
          context = OpenSSL::SSL::Context::Client.new
        else
          context = tls
        end
        socket = OpenSSL::SSL::Socket::Client.new(socket, context: context, sync_close: true)
      end
    {% end %}

    headers["Host"] = "#{host}:#{port}"
    headers["Connection"] = "Upgrade"
    headers["Upgrade"] = "websocket"
    headers["Sec-WebSocket-Version"] = VERSION.to_s
    headers["Sec-WebSocket-Key"] = Base64.strict_encode(StaticArray(UInt8, 16).new { rand(256).to_u8 })

    path = "/" if path.empty?
    handshake = HTTP::Request.new("GET", path, headers)
    handshake.to_io(socket)
    socket.flush
    handshake_response = HTTP::Client::Response.from_io(socket)
    unless handshake_response.status_code == 101
      raise Socket::Error.new("Handshake got denied. Status code was #{handshake_response.status_code}")
    end

    new(socket, masked: true)
  end

  def self.new(uri : URI | String, headers = HTTP::Headers.new)
    uri = URI.parse(uri) if uri.is_a?(String)

    if (host = uri.host) && (path = uri.full_path)
      tls = uri.scheme == "https" || uri.scheme == "wss"
      return new(host, path, uri.port, tls, headers)
    end

    raise ArgumentError.new("No host or path specified which are required.")
  end
end

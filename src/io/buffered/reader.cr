# The BufferedIO mixin enhances the IO module with input buffering.
#
# Additionally, several methods, like `#gets`, are implemented in a more
# efficient way.
module IO::Buffered::Reader
  BUFFER_SIZE = IO::Buffered::Common::BUFFER_SIZE

  # Due to https://github.com/manastech/crystal/issues/456 this
  # initialization logic must be copied in the included type's
  # initialize method:
  #
  # def initialize
  #   @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
  # end

  # Reads at most *slice.size* bytes from the wrapped IO into *slice*. Returns the number of bytes read.
  abstract def unbuffered_read(slice : Slice(UInt8))

  # Closes the wrapped IO.
  abstract def unbuffered_close

  # :nodoc:
  def gets(delimiter : Char, limit : Int)
    if delimiter.ord >= 128
      return super
    end

    raise ArgumentError.new "negative limit" if limit < 0

    limit = Int32::MAX if limit < 0

    delimiter_byte = delimiter.ord.to_u8

    # We first check, after filling the buffer, if the delimiter
    # is already in the buffer. In that case it's much faster to create
    # a String from a slice of the buffer instead of appending to a
    # StringIO, which happens in the other case.
    fill_buffer if @in_buffer_rem.empty?
    if @in_buffer_rem.empty?
      return nil
    end

    index = @in_buffer_rem.index(delimiter_byte)
    if index
      # If we find it past the limit, limit the result
      if index > limit
        index = limit
      else
        index += 1
      end

      string = String.new(@in_buffer_rem[0, index])
      @in_buffer_rem += index
      return string
    end

    # We didn't find the delimiter, so we append to a StringIO until we find it,
    # or we reach the limit
    String.build do |buffer|
      loop do
        available = Math.min(@in_buffer_rem.size, limit)
        buffer.write @in_buffer_rem[0, available]
        @in_buffer_rem += available
        limit -= available

        if limit == 0
          break
        end

        fill_buffer if @in_buffer_rem.empty?

        if @in_buffer_rem.empty?
          if buffer.bytesize == 0
            return nil
          else
            break
          end
        end

        index = @in_buffer_rem.index(delimiter_byte)
        if index
          if index > limit
            index = limit
          else
            index += 1
          end
          buffer.write @in_buffer_rem[0, index]
          @in_buffer_rem += index
          break
        end
      end
    end
  end

  # :nodoc:
  def read_byte : UInt8?
    fill_buffer if @in_buffer_rem.empty?
    if @in_buffer_rem.empty?
      nil
    else
      b = @in_buffer_rem[0]
      @in_buffer_rem += 1
      b
    end
  end

  private def read_char_with_bytesize
    return super unless @in_buffer_rem.size >= 4

    first = @in_buffer_rem[0].to_u32
    if first < 0x80
      @in_buffer_rem += 1
      return first.chr, 1
    end

    second = (@in_buffer_rem[1] & 0x3f).to_u32
    if first < 0xe0
      @in_buffer_rem += 2
      return ((first & 0x1f) << 6 | second).chr, 2
    end

    third = (@in_buffer_rem[2] & 0x3f).to_u32
    if first < 0xf0
      @in_buffer_rem += 3
      return ((first & 0x0f) << 12 | (second << 6) | third).chr, 3
    end

    fourth = (@in_buffer_rem[3] & 0x3f).to_u32
    if first < 0xf8
      @in_buffer_rem += 4
      return ((first & 0x07) << 18 | (second << 12) | (third << 6) | fourth).chr, 4
    end

    raise InvalidByteSequenceError.new
  end

  # Buffered implementation of `IO#read(slice)`.
  def read(slice : Slice(UInt8))
    count = slice.size
    return 0 if count == 0

    if @in_buffer_rem.empty?
      # If we are asked to read more than the buffer's size,
      # read directly into the slice.
      if count >= BUFFER_SIZE
        return unbuffered_read(slice[0, count]).to_i
      else
        fill_buffer
        return 0 if @in_buffer_rem.empty?
      end
    end

    to_read = Math.min(count, @in_buffer_rem.size)
    slice.copy_from(@in_buffer_rem.pointer(to_read), to_read)
    @in_buffer_rem += to_read
    to_read
  end

  # :nodoc:
  def read(count : Int)
    raise ArgumentError.new "negative count" if count < 0

    fill_buffer if @in_buffer_rem.empty?

    # If we have enough content in the buffer, use it
    if count <= @in_buffer_rem.size
      string = String.new(@in_buffer_rem[0, count])
      @in_buffer_rem += count
      return string
    end

    super
  end

  private def fill_buffer
    in_buffer = in_buffer()
    size = unbuffered_read(Slice.new(in_buffer, BUFFER_SIZE)).to_i
    @in_buffer_rem = Slice.new(in_buffer, size)
  end

  private def in_buffer
    @in_buffer ||= GC.malloc_atomic(BUFFER_SIZE.to_u32) as UInt8*
  end
end

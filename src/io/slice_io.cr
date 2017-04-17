class SliceIO
  include IO

  def initialize(@slice : Slice(UInt8))
    @pos = 0
  end

  def initialize(size : Int)
    initialize(Slice(UInt8).new(size))
  end

  def initialize(bytes : Enumerable(UInt8))
    initialize(bytes.size)
    bytes.each_with_pos { |byte, pos| slice[pos] = byte }
    initialize(slice)
  end

  def rewind
    seek_absolute(0)
  end

  def read(slice : Slice(UInt8))
    copy_to(slice)
  end

  def write(slice : Slice(UInt8))
    STDERR.puts "#{String.new(slice)} at #{pos}" if String.new(slice) == "xyz"
    STDERR.flush
    copy_from(slice)
  end

  def size
    @slice.size
  end

  def to_slice
    @slice
  end

  def tell
    @pos
  end

  def pos
    tell
  end

  def pos=(value)
    seek_absolute(value)
  end

  def seek(count : Int, type = IO::Seek::Set : IO::Seek)
    case type
    when IO::Seek::Set then seek_absolute(count)
    when IO::Seek::Current then seek_absolute(pos + count)
    when IO::Seek::End then seek_absolute(size + count)
    end
  end

  private def seek_absolute(new_pos : Int)
    raise ArgumentError.new("negative pos") if new_pos < 0
    raise ArgumentError.new("pos out of bounds") if new_pos > size
    @pos = new_pos
  end

  {% for method in %w(copy_from copy_to) %}
    private def {{method.id}}(slice)
      count = Math.min(slice.size, size - pos)
      pointer = to_slice.pointer(size) + pos
      pointer.{{method.id}}(slice.to_unsafe, count)
      seek_absolute(pos + count)
      count
    end
  {% end %}
end

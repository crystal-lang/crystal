class RaiseIOError < IO
  getter writes = 0

  def initialize(@raise_on_write = false)
  end

  def read(slice : Bytes)
    raise IO::Error.new("...")
  end

  def write(slice : Bytes) : Nil
    @writes += 1
    raise IO::Error.new("...") if @raise_on_write
  end

  def flush
    raise IO::Error.new("...")
  end
end

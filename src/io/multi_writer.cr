# An `IO` which writes to a number of underlying writer IOs.
#
# ```
# io1 = IO::Memory.new
# io2 = IO::Memory.new
# writer = IO::MultiWriter.new(io1, io2)
# writer.puts "foo bar"
# io1.to_s # => "foo bar\n"
# io2.to_s # => "foo bar\n"
# ```
class IO::MultiWriter < IO
  # If `#sync_close?` is `true`, closing this `IO` will close all of the underlying
  # IOs.
  property? sync_close
  getter? closed = false

  @writers : Array(IO)

  # Creates a new `IO::MultiWriter` which writes to *writers*. If
  # *sync_close* is set, calling `#close` calls `#close` on all underlying
  # writers.
  def initialize(@writers : Array(IO), @sync_close = false)
  end

  # Creates a new `IO::MultiWriter` which writes to *writers*. If
  # *sync_close* is set, calling `#close` calls `#close` on all underlying
  # writers.
  def initialize(*writers : IO, @sync_close = false)
    @writers = writers.map(&.as(IO)).to_a
  end

  def write(slice : Bytes)
    check_open

    @writers.each { |writer| writer.write(slice) }
  end

  def read(slice : Bytes)
    raise IO::Error.new("Can't read from IO::MultiWriter")
  end

  def close
    return if @closed
    @closed = true

    @writers.each { |writer| writer.close } if sync_close?
  end
end

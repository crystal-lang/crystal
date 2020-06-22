# A `Log::Backend` that emits to an `IO` (defaults to STDOUT).
class Log::IOBackend < Log::Backend
  property io : IO
  property formatter : Formatter

  def initialize(@io = STDOUT, *, @formatter : Formatter = ShortFormat)
    @mutex = Mutex.new(:unchecked)
  end

  def write(entry : Entry)
    @mutex.synchronize do
      format(entry)
      io.puts
      io.flush
    end
  end

  # Emits the *entry* to the given *io*.
  # It uses the `#formatter` to convert.
  def format(entry : Entry)
    @formatter.format(entry, io)
  end
end

# A `Log::Backend` that emits to an `IO` (defaults to STDOUT).
class Log::IOBackend < Log::Backend
  property io : IO
  property progname : String
  property formatter : Formatter? = nil

  def initialize(@io = STDOUT)
    @mutex = Mutex.new(:unchecked)
    @progname = File.basename(PROGRAM_NAME)
  end

  def write(entry : Entry)
    @mutex.synchronize do
      format(entry)
      io.puts
      io.flush
    end
  end

  # Emits the *entry* to the given *io*.
  # It will use the `#formatter` if defined, otherwise will call `#default_format`.
  def format(entry : Entry)
    if formatter = @formatter
      formatter.call(entry, io)
    else
      default_format(entry)
    end
  end

  # Emits the *entry* to the given *io*.
  def default_format(entry : Entry)
    label = entry.severity.label
    io << label[0] << ", ["
    entry.timestamp.to_rfc3339(io)
    io << " #" << Process.pid << "] "
    label.rjust(7, io)
    io << " -- " << @progname << ":" << entry.source << ": " << entry.message
    if entry.context.size > 0
      io << " -- " << entry.context
    end
    if ex = entry.exception
      io << " -- " << ex.class << ": " << ex
    end
  end
end

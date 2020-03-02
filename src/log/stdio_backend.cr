# A `Log::Backend` that emits to STDOUT.
class Log::StdioBackend < Log::Backend
  # TODO allow emitting entries from certain level to stderr

  # :nodoc:
  property stdout : IO = STDOUT

  property progname : String
  property formatter : Formatter? = nil

  def initialize
    @mutex = Mutex.new(:unchecked)
    @progname = File.basename(PROGRAM_NAME) || ""
  end

  def write(entry : Entry)
    @mutex.synchronize do
      if formatter = @formatter
        formatter.call(entry, stdout)
      else
        format(entry, stdout)
      end
      stdout.puts
      stdout.flush
    end
  end

  # Emits the *entry* to the given *io*.
  def format(entry : Entry, io : IO)
    label = entry.severity.to_s.upcase
    io << label[0] << ", [" << entry.timestamp << " #" << Process.pid << "] "
    io << label.rjust(7) << " -- " << @progname << ":" << entry.source << ": " << entry.message
    if entry.context.size > 0
      io << " -- " << entry.context
    end
    if ex = entry.exception
      io << " -- " << ex.class << ": " << ex
    end
  end
end

# A `Log::Backend` that emits to an `IO` (defaults to STDOUT).
class Log::IOBackend < Log::Backend
  property io : IO
  property formatter : Formatter

  {% if flag?(:win32) %}
    private DEFAULT_DISPATCHER = DispatchMode::Sync
  {% else %}
    private DEFAULT_DISPATCHER = DispatchMode::Async
  {% end %}

  def initialize(@io = STDOUT, *, @formatter : Formatter = ShortFormat, dispatcher : Dispatcher::Spec? = nil)
    super(dispatcher || DEFAULT_DISPATCHER)
  end

  def write(entry : Entry)
    format(entry)
    io.puts
    io.flush
  end

  # Emits the *entry* to the given *io*.
  # It uses the `#formatter` to convert.
  def format(entry : Entry)
    @formatter.format(entry, io)
  end
end

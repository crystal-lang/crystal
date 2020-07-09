# A `Log::Backend` that emits to an `IO` (defaults to STDOUT).
class Log::IOBackend < Log::Backend
  property io : IO
  property formatter : Formatter

  {% if flag?(:win32) %}
    # TODO: this constructor must go away once channels are fixed in Windows
    def initialize(@io = STDOUT, *, @formatter : Formatter = ShortFormat, dispatcher : Dispatcher::Spec = DispatchMode::Sync)
      super(dispatcher)
    end
  {% else %}
    def initialize(@io = STDOUT, *, @formatter : Formatter = ShortFormat, dispatcher : Dispatcher::Spec = DispatchMode::Async)
      super(dispatcher)
    end
  {% end %}

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

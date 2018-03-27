class Logger
  # The `Adapter` module can be used to supply behaviors to `Logger` other
  # than writing to an `IO`, such as appending logs to a database or
  # shipping them via a particular protocal. All that needs to be done is to
  # include `Adapter` in a class, define `#write`, and pass an instance to
  # the constructor of `Logger`.
  module Adapter
    # Receives log data from a `Logger` and does something with it, typically
    # persisting the message somewhere or shipping it to a log aggregator.
    abstract def write(severity : Logger::Severity, datetime : Time, progname : String, message : String)
  end

  # `IOAdapter` is the built-in `Adapter`. It is automatically
  # instantiated when passing an `IO` to `Logger.new`.
  class IOAdapter
    include Adapter

    alias Formatter = Severity, Time, String, String, IO ->
    # Customizable `Proc` (with a reasonable default)
    # which the `IOAdapter` uses to format and print its entries.
    #
    # Use this setter to provide a custom formatter.
    # The `IOAdapter` will invoke it with the following arguments:
    #  - severity: a `Logger::Severity`
    #  - datetime: `Time`, the entry's timestamp
    #  - progname: `String`, the program name, if set when the logger was built
    #  - message: `String`, the body of a message
    #  - io: `IO`, the Logger's stream, to which you must write the final output
    #
    # Example:
    #
    # ```
    # require "logger"
    #
    # formatter = Logger::IOAdapter::Formatter.new do |severity, datetime, progname, message, io|
    #   case severity
    #   when .>= Logger::ERROR
    #     io << "!!"
    #   when .>= Logger::INFO
    #     io << "--"
    #   else
    #     io << ".."
    #   end
    #   io << ' ' << datetime << ' ' << severity.to_s.rjust(5) << ' ' << progname << ": " << message
    # end
    #
    # logger = Logger.new(STDOUT, formatter: formatter, progname: "YodaBot")
    # logger.warn("Fear leads to anger. Anger leads to hate. Hate leads to suffering.")
    #
    # # Prints to the console:
    # # "-- 2017-05-06 18:00:41 -03:00  WARN YodaBot: Fear leads to anger.
    # # Anger leads to hate. Hate leads to suffering."
    # ```
    property formatter : Formatter
    DEFAULT_FORMATTER = Formatter.new do |severity, datetime, progname, message, io|
      label = severity.unknown? ? "ANY" : severity.to_s
      io << label[0] << ", [" << datetime << " #" << Process.pid << "] "
      io << label.rjust(5) << " -- " << progname << ": " << message
    end

    # Creates a new IOLogAdapter. If not supplied with a `formatter`, a
    # default is used.
    def initialize(@io : IO, @formatter = DEFAULT_FORMATTER)
      @closed = false
      @mutex = Mutex.new
    end

    # Writes a message to `@io`.
    def write(severity, datetime, progname, message)
      @mutex.synchronize do
        @formatter.call(severity, datetime, progname.to_s, message.to_s, @io)
        @io.puts
        @io.flush
      end
    end

    # Calls the *close* method on the object passed to `initialize`.
    def close
      return if @closed
      @closed = true

      @mutex.synchronize do
        @io.close
      end
    end
  end
end

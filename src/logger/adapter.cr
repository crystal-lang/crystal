class Logger
  # The `Adapter` module can be used to supply log writing behaviors such as
  # appending to an `IO` or shipping them via a particular protocal. All that
  # needs to be done is to include `Adapter` in a class and define `#write`.
  module Adapter
    # Receives log data from a `Logger` and does something with it, typically
    # persisting the message somewhere or shipping it to a log aggregator.
    abstract def write(severity : Severity, message : String, time : Time, component : String)
  end

  # `IOAdapter` is the built-in `Adapter`. It formats log messages nicely and
  # then writes them to an `IO`. The default handler uses an `IOAdapter` that
  # writes to `STDERR`.
  class IOAdapter
    include Adapter

    # The name of the program, as should be included in log messages.
    getter program_name : String

    # The `IO` object to be written to.
    getter io

    # Creates a new `IOAdapter`. If not supplied with a program name, the
    # filename of the running executable is used.
    def initialize(@io : IO, program_name = File.basename(PROGRAM_NAME))
      @program_name = program_name.to_s
      @closed = false
      @mutex = Mutex.new
    end

    # Writes a message to `@io`.
    def write(severity : Severity, message : String, time : Time, component : String)
      @mutex.synchronize do
        format(severity, message, time, component)
        @io.puts
        @io.flush
      end
    end

    # Formats a single log entry and prints it to the given `IO`.
    #
    # To provide a custom formatter, subclass `IOAdapter` and override this method.
    # Example:
    #
    # ```
    # require "logger"
    #
    # class MyAdapter < Logger::IOAdapter
    #   def format(severity, message, time, component)
    #     case severity
    #     when .>= Logger::ERROR
    #       @io << "!!"
    #     when .>= Logger::INFO
    #       @io << "--"
    #     else
    #       @io << ".."
    #     end
    #     @io << ' ' << time << ' ' << severity.to_s << ' ' << @program_name << ": " << message
    #   end
    # end
    #
    # Logger.default_handler.adapters = [MyAdapter.new(STDERR, program_name: "YodaBot")] of Logger::Adapter
    # logger = Logger.new
    # logger.warn("Fear leads to anger. Anger leads to hate. Hate leads to suffering.")
    #
    # # Prints to the console:
    # # -- 2018-03-29 00:13:38 -07:00 WARN YodaBot: Fear leads to anger. Anger leads to hate. Hate leads to suffering.
    # ```
    def format(severity, message, time, component)
      label = severity.unknown? ? "ANY" : severity.to_s
      @io << label[0] << ", [" << time << " #" << Process.pid << "] " << label.rjust(5)
      @io << " -- " << @program_name unless @program_name.empty?
      @io << " / " << component unless component.empty?
      @io << ": " << message
    end
  end
end

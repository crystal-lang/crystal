class Logger
  # The `Adapter` module can be used to supply behaviors to `Logger` other
  # than writing to an `IO`, such as appending logs to a database or
  # shipping them via a particular protocal. All that needs to be done is to
  # include `Adapter` in a class, define `#write`, and pass an instance to
  # the constructor of `Logger`.
  module Adapter
    # Receives log data from a `Logger` and does something with it, typically
    # persisting the message somewhere or shipping it to a log aggregator.
    abstract def write(severity : Severity, message : String, time : Time, component : String)
  end

  # `IOAdapter` is the built-in `Adapter`. It is automatically
  # instantiated when passing an `IO` to `Logger.new`.
  class IOAdapter
    include Adapter

    # The name of the program, as should be included in log messages.
    getter program_name : String

    # Creates a new IOLogAdapter. If not supplied with a program name, the
    # filename of the running executable is used.
    def initialize(@io : IO, program_name = self.class.find_program_name)
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

    # Calls the *close* method on the object passed to `initialize`.
    def close
      return if @closed
      @closed = true

      @mutex.synchronize do
        @io.close
      end
    end

    protected def self.find_program_name
      if path = Process.executable_path
        File.basename(path)
      else
        ""
      end
    end

    # Formats a single `Logger::Entry` and prints it to the given `IO`.
    #
    # To provide a custom formatter, simply subclass `IOAdapter` and override this method.
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
    # logger = Logger.new(MyAdapter.new(STDERR, program_name: "YodaBot"))
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

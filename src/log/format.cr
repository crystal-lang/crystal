class Log
  # The program name used for log entries
  #
  # Defaults to the executable name
  class_property progname = File.basename(PROGRAM_NAME)

  # The current process PID
  protected class_getter pid : String = Process.pid.to_s

  # Base interface to convert log entries and write them to an `IO`
  module Formatter
    # Writes a `Log::Entry` through an `IO`
    abstract def format(entry : Log::Entry, io : IO)

    # Creates an instance of a `Log::Formatter` that calls
    # the specified `Proc` for every entry
    def self.new(&proc : (Log::Entry, IO) ->) : self
      ProcFormatter.new proc
    end
  end

  # :nodoc:
  private struct ProcFormatter
    include Formatter

    def initialize(@proc : (Log::Entry, IO) ->)
    end

    def format(entry : Log::Entry, io : IO) : Nil
      @proc.call(entry, io)
    end
  end

  # Base implementation of `Log::Formatter` to convert
  # log entries into text representation
  #
  # This can be used to create efficient formatters:
  # ```
  # require "log"
  #
  # struct MyFormat < Log::StaticFormatter
  #   def run
  #     string "- "
  #     severity
  #     string ": "
  #     message
  #   end
  # end
  #
  # Log.setup(:info, Log::IOBackend.new(formatter: MyFormat))
  # Log.info { "Hello" }    # => -   INFO: Hello
  # Log.error { "Oh, no!" } # => -  ERROR: Oh, no!
  # ```
  #
  # There is also a helper macro to generate these formatters. Here's
  # an example that generates the same result:
  # ```
  # Log.define_formatter MyFormat, "- #{severity}: #{message}"
  # ```
  abstract struct StaticFormatter
    extend Formatter

    def initialize(@entry : Log::Entry, @io : IO)
    end

    # Write the entry timestamp in RFC3339 format
    def timestamp : Nil
      @entry.timestamp.to_rfc3339(@io, fraction_digits: 6)
    end

    # Write a fixed string
    def string(str : _) : Nil
      @io << str
    end

    # Write the message of the entry
    def message : Nil
      @io << @entry.message
    end

    # Write the severity
    #
    # This writes the severity in uppercase and left padded
    # with enough space so all the severities fit
    def severity : Nil
      @entry.severity.label.rjust(@io, 6)
    end

    # Write the source for non-root entries
    #
    # It doesn't write any output for entries generated from the root logger.
    # Parameters `before` and `after` can be provided to be written around
    # the value.
    # ```
    # Log.define_formatter TestFormatter, "#{source(before: '[', after: "] ")}#{message}"
    # Log.setup(:info, Log::IOBackend.new(formatter: TestFormatter))
    # Log.for("foo.bar").info { "Hello" } # => - [foo.bar] Hello
    # ```
    def source(*, before : _ = nil, after : _ = nil) : Nil
      if @entry.source.size > 0
        @io << before << @entry.source << after
      end
    end

    # Write all the values from the entry data
    #
    # It doesn't write any output if the entry data is empty.
    # Parameters `before` and `after` can be provided to be written around
    # the value.
    def data(*, before : _ = nil, after : _ = nil) : Nil
      unless @entry.data.empty?
        @io << before << @entry.data << after
      end
    end

    # Write all the values from the context
    #
    # It doesn't write any output if the context is empty.
    # Parameters `before` and `after` can be provided to be written around
    # the value.
    def context(*, before : _ = nil, after : _ = nil) : Nil
      unless @entry.context.empty?
        @io << before << @entry.context << after
      end
    end

    # Write the exception, including backtrace
    #
    # It doesn't write any output unless there is an exception in the entry.
    # Parameters `before` and `after` can be provided to be written around
    # the value. `before` defaults to `'\n'` so the exception is written
    # on a separate line
    def exception(*, before : _ = '\n', after : _ = nil) : Nil
      if ex = @entry.exception
        @io << before
        ex.inspect_with_backtrace(@io)
        @io << after
      end
    end

    # Write the program name. See `Log.progname`.
    def progname : Nil
      @io << Log.progname
    end

    # Write the current process identifier
    def pid(*, before = '#', after = nil)
      @io << before << Log.pid << after
    end

    # Write the `Log::Entry` to the `IO` using this pattern
    def self.format(entry : Log::Entry, io : IO) : Nil
      new(entry, io).run
    end

    # Subclasses must implement this method to define the output pattern
    abstract def run
  end

  # Generate subclasses of `Log::StaticFormatter` from a string with interpolations
  #
  # Example:
  # ```
  # Log.define_formatter MyFormat, "- #{severity}: #{message}"
  # ```
  # See `Log::StaticFormatter` for the available methods that can
  # be called within the interpolations.
  macro define_formatter(name, pattern)
    struct {{ name }} < ::Log::StaticFormatter
      def run
        {% for part in pattern.expressions %}
          {% if part.is_a?(StringLiteral) %}
            string {{ part }}
          {% else %}
            {{ part }}
          {% end %}
        {% end %}
      end
    end
  end
end

# Default short format
#
# It writes log entries with the following format:
# ```
# 2020-05-07T17:40:07.994508000Z   INFO - my.source: Initializing everything
# ```
#
# When the entries have context data it's also written to the output:
# ```
# 2020-05-07T17:40:07.994508000Z   INFO - my.source: Initializing everything -- {"data" => 123}
# ```
#
# Exceptions are written in a separate line:
# ```
# 2020-05-07T17:40:07.994508000Z  ERROR - my.source: Something failed
# Oh, no (Exception)
#   from ...
# ```
Log.define_formatter Log::ShortFormat, "#{timestamp} #{severity} - #{source(after: ": ")}#{message}" \
                                       "#{data(before: " -- ")}#{context(before: " -- ")}#{exception}"

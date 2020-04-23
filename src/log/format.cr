class Log
  class_property progname = File.basename(PROGRAM_NAME)

  module Formatter
    abstract def format(entry : Log::Entry, io : IO)

    def self.new(&proc : (Log::Entry, IO) ->)
      ProcFormatter.new proc
    end
  end

  private struct ProcFormatter
    include Formatter

    def initialize(@proc : (Log::Entry, IO) ->)
    end

    def format(entry : Log::Entry, io : IO)
      @proc.call(entry, io)
    end
  end

  abstract struct StaticFormat
    extend Formatter

    def initialize(@entry : Log::Entry, @io : IO)
    end

    def timestamp
      @entry.timestamp.to_rfc3339(@io)
    end

    def string(str)
      @io << str
    end

    def message
      @io << @entry.message
    end

    def severity
      @entry.severity.label.rjust(7, @io)
    end

    def source(*, before = nil, after = nil)
      if @entry.source.size > 0
        @io << before << @entry.source << after
      end
    end

    def data(*, before = nil, after = nil)
      if @entry.data.size > 0
        @io << before << @entry.data << after
      end
    end

    def context(*, before = nil, after = nil)
      if @entry.context.size > 0
        @io << before << @entry.context << after
      end
    end

    def exception(*, before = '\n', after = nil)
      if ex = @entry.exception
        @io << before
        ex.inspect_with_backtrace(@io)
        @io << after
      end
    end

    def progname
      @io << Log.progname
    end

    def self.format(entry, io)
      new(entry, io).run
    end

    abstract def run
  end

  macro format(name, pattern)
    struct {{name}} < ::Log::StaticFormat
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

Log.format Log::ShortFormat, "#{timestamp} #{severity} - #{source(after: ": ")}#{message}" \
                             "#{data(before: " -- ")}#{context(before: " -- ")}#{exception}"

require "colorize"
require "string_pool"

module Crystal
  module Tracing
    WORDS_DICTIONNARY = StringPool.new

    class Values(T)
      getter size : T = T.zero
      getter sum : T = T.zero
      getter min : T = T::MAX
      getter max : T = T::MIN
      @sum_square : T

      def initialize
        @sum_square = T.zero
      end

      def <<(value)
        v = T.new(value)
        @size += 1
        @sum += v
        @min = v if v < @min
        @max = v if v > @max
        @sum_square += v ** 2
      end

      def average
        size > 0 ? sum / size : T.zero
      end

      def stddev
        if size > 0
          Math.sqrt((@sum_square / size) - (average ** 2))
        else
          T.zero
        end
      end

      def humanize(io, value)
        value.humanize(io)
      end

      def to_s(io : IO) : Nil
        io << "[total="
        humanize io, sum
        io << " min="
        humanize io, min
        io << " max="
        humanize io, max
        io << " mean="
        humanize io, average
        io << " ±"
        humanize io, stddev
        io << ']'
      end
    end

    class Durations < Values(Float64)
      def humanize(io, value)
        value.humanize(io)
        io << 's'
      end
    end

    class Sizes < Values(Int64)
      def humanize(io, value)
        value.humanize(io)
        io << 'B'
      end
    end

    struct Parser
      def self.parse_event(line : String) : Event?
        parser = new(Char::Reader.new(line))
        parser.parse_event
      end

      def self.parse_variable(line : String, name : String) : Int64?
        return unless pos = line.index(name)
        parser = new(Char::Reader.new(line, pos + name.bytesize))
        return unless parser.expect '='
        parser.parse_integer
      end

      def initialize(@reader : Char::Reader)
      end

      def parse_event : Event?
        return unless section = parse_word
        return unless expect ' '
        return unless operation = parse_word
        return unless expect ' '
        return unless expect 't'
        return unless expect '='
        return unless time = parse_nanoseconds
        return unless expect ' '
        return unless expect 'd'
        return unless expect '='
        return unless duration = parse_nanoseconds
        Event.new(section, operation, time, duration, @reader.string)
      end

      # Tries to parse known words, so we can return static strings instead of
      # dynamically allocating the same string over and over, then falls back to
      # allocate a string.
      protected def parse_word
        pos = @reader.pos

        loop do
          char = @reader.current_char
          return unless char.ascii_letter? || {'-', '_', ':'}.includes?(char)
          break if @reader.next_char == ' '
        end

        WORDS_DICTIONNARY.get(@reader.string.to_slice[pos...@reader.pos])
      end

      # Parses an integer directly without allocating a dynamic string.
      protected def parse_integer
        int = 0_i64
        neg = false

        if @reader.current_char == '-'
          @reader.next_char
          neg = true
        elsif @reader.current_char == '+'
          @reader.next_char
        end

        char = @reader.current_char
        while char.ascii_number?
          int = int * 10_i64 + char.to_i64
          char = @reader.next_char
        end

        neg ? -int : int
      end

      protected def parse_nanoseconds : Float64
        parse_integer.try(&.fdiv(Time::NANOSECONDS_PER_SECOND))
      end

      protected def parse_char(*chars)
        char = @reader.current_char

        if chars.includes?(char)
          @reader.next_char
          char
        end
      end

      protected def expect(char)
        if @reader.current_char == char
          @reader.next_char
        end
      end
    end

    struct Event
      getter section : String
      getter operation : String
      getter time : Float64
      @duration : Float64
      getter line : String

      def initialize(@section, @operation, @time, @duration, @line)
      end

      def variable(name : String)
        Parser.parse_variable(line, name)
      end

      def duration?
        @duration unless @duration.negative?
      end
    end

    class Data
      property events : UInt64
      property duration : Float64
      getter values : Hash(Symbol, Values(Float64))

      def initialize
        @events = 0_u64
        @duration = 0_f64
        @values = {} of Symbol => Values(Float64)
      end

      def durations
        @durations ||= Durations.new
      end

      def sizes
        @sizes ||= Sizes.new
      end

      def each(&)
        yield :events, @events

        if durations = @durations
          yield :durations, durations
        elsif (duration = @duration) > 0
          yield :duration, duration.round(9)
        end

        if sizes = @sizes
          yield :sizes, sizes
        end

        @values.each do |key, value|
          yield key, value
        end
      end
    end

    class StatsCommand
      alias Action = Hash(String, Data)
      alias Section = Hash(String, Action)

      @stdin : IO
      @stdout : IO
      @stderr : IO

      def initialize(
        @path : String,
        @color = false,
        @fast = false,
        @stdin = STDIN,
        @stdout = STDOUT,
        @stderr = STDERR
      )
      end

      def run
        stats = Section.new do |h, k|
          h[k] = Action.new do |h, k|
            h[k] = Data.new
          end
        end

        each_event do |event|
          data = stats[event.section][event.operation]
          data.events += 1

          if duration = event.duration?
            if @fast
              data.duration += duration
            else
              data.durations << duration
            end
          end

          next if @fast

          if event.section == "gc"
            if event.operation == "malloc"
              if size = event.variable("size")
                data.sizes << size
              end
            end
          end
        end

        stats.each do |section, actions|
          actions.each do |operation, data|
            Colorize.with.toggle(@color).yellow.surround(@stdout) do
              @stdout << section << ':' << operation
            end

            data.each do |key, value|
              @stdout << ' ' << key << '='
              value.to_s(@stdout)
            end

            @stdout << '\n'
          end
        end
      end

      private def each_event(&)
        open_trace_file do |input|
          while line = input.gets(chomp: true)
            if event = Parser.parse_event(line)
              yield event
            elsif @path != "-"
              @stderr.print "WARN: invalid trace '"
              @stderr.print line
              @stderr.print "'\n"
            end
          end
        end
      end

      private def open_trace_file(&)
        if @path == "-"
          yield @stdin
        else
          File.open(@path, "r") { |file| yield file }
        end
      end
    end
  end
end

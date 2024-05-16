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
        io << value.round(9)
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
        value = value.abs

        if value >= 1
          io << value.round(2)
          io << 's'
        elsif value > 0.001
          io << (value * 1_000).to_i64
          io << "ms"
        elsif value > 0.000_001
          io << (value * 1_000_000).to_i64
          io << "us"
        else
          io << (value * 1_000_000_000).to_i64
          io << "ns"
        end
      end
    end

    class Sizes < Values(UInt64)
      KILOBYTE = 1024
      MEGABYTE = 1024 * 1024
      GIGABYTE = 1024 * 1024 * 1024

      def humanize(io, value)
        value = value.abs.to_u64

        if value >= GIGABYTE
          io << (value // GIGABYTE)
          io << "GB"
        elsif value >= MEGABYTE
          io << (value // MEGABYTE)
          io << "MB"
        elsif value >= KILOBYTE
          io << (value // KILOBYTE)
          io << "KB"
        else
          io << value
          io << 'B'
        end
      end
    end

    module Parser
      def self.parse_event(line : String) : Event?
        reader = Char::Reader.new(line)
        section = parse_word
        expect ' '
        action = parse_word
        expect ' '
        expect 't'
        expect '='
        time = parse_integer / 1_000_000_000 # nanoseconds
        expect ' '
        expect 'd'
        expect '='
        duration = parse_integer / 1_000_000_000 # nanoseconds
        Event.new(section, action, time, duration, line)
      end

      def self.parse_variable(line : String, name : String) : Int64?
        if pos = line.index(name)
          reader = Char::Reader.new(line, pos + name.bytesize + 1)
          expect '='
          parse_integer
        end
      end

      # Tries to parse known words, so we can return static strings instead of
      # dynamically allocating the same string over an over, then falls back to
      # allocate a string.
      private macro parse_word
        pos = reader.pos

        loop do
          %char = reader.current_char
          return unless %char.ascii_letter? || {'-', '_', ':'}.includes?(%char)
          break if reader.next_char == ' '
        end

        WORDS_DICTIONNARY.get(reader.string.to_slice[pos...reader.pos])
      end

      # Parses an integer directly without allocating a dynamic string.
      private macro parse_integer
        %int = 0_i64
        %neg = false

        if reader.current_char == '-'
          reader.next_char
          %neg = true
        elsif reader.current_char == '+'
          reader.next_char
        end

        %char = reader.current_char
        while %char.ascii_number?
          %int = %int * 10_i64 + %char.to_i64
          %char = reader.next_char
        end

        %neg ? -%int : %int
      end

      private macro parse_t
        %char = reader.current_char
        if {'t', 'd'}.includes?(%char)
          reader.next_char
          %char
        else
          return
        end
      end

      private macro parse_char(*chars)
        %char = reader.current_char
        if {{chars}}.includes?(%char)
          reader.next_char
          %char
        else
          return
        end
      end

      private macro expect(char)
        if reader.current_char == {{char}}
          reader.next_char
        else
          return
        end
      end
    end

    struct Event
      getter section : String
      getter action : String
      getter time : Float64
      @duration : Float64
      getter line : String

      def initialize(@section, @action, @time, @duration, @line)
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
          data = stats[event.section][event.action]
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
            if event.action == "malloc"
              if size = event.variable("size")
                data.sizes << size.to_i32
              end
            end
          end
        end

        stats.each do |section, actions|
          actions.each do |action, data|
            Colorize.with.toggle(@color).yellow.surround(@stdout) do
              @stdout << section << ':' << action
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

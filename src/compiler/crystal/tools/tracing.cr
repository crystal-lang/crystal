require "colorize"

module Crystal
  module Tracing
    # List of known words used by trace calls, so we can return static strings
    # instead of dynamically allocating the same few strings over an over. This
    # dramatically improves performance when parsing large traces.
    WORDS_DICTIONNARY = %w[
      gc
      malloc
      realloc
      collect:mark
      collect:sweep
      collect

      sched
      heap_resize
      spawn
      enqueue
      resume
      reschedule
      sleep
      event_loop
      mt:sleeping
      mt:slept
    ]

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

        t = parse_char('t', 'd')
        expect '='
        time = parse_float

        Event.new(section, action, t, time, line)
      end

      def self.parse_variable(line : String, name : String) : Float64?
        if pos = line.index(name)
          reader = Char::Reader.new(line, pos + name.bytesize + 1)
          expect '='
          parse_float
        end
      end

      # Tries to parse known words, so we can return static strings instead of
      # dynamically allocating the same string over an over, then falls back to
      # allocate a string.
      private macro parse_word
        pos = reader.pos
        case
          {% for word in WORDS_DICTIONNARY %}
          when parse_word?({{word}})
            {{word}}
          {% end %}
        else
          loop do
            %char = reader.current_char
            return unless %char.ascii_letter? || {'-', '_', ':'}.includes?(%char)
            break if reader.next_char == ' '
          end
          reader.string[pos...reader.pos]
        end
      end

      private macro parse_word?(string)
        %valid = true
        {{string}}.each_char do |%char|
          if reader.current_char == %char
            reader.next_char
          else
            reader.pos = pos
            %valid = false
            break
          end
        end
        %valid
      end

      # Parses a float directly using a stack allocated buffer instead of
      # allocating a dynamic string.
      private macro parse_float
        %buf = uninitialized UInt8[128]
        %i = -1
        loop do
          %char = reader.current_char
          return unless %char.ascii_number? || %char == '.'
          %buf[%i += 1] = %char.ord.to_u8!
          break if reader.next_char == ' '
        end
        %buf[%i] = 0_u8
        LibC.strtod(%buf, nil)
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
      getter t : Char
      getter time : Float64
      getter line : String

      def initialize(@section, @action, @t, @time, @line)
      end

      def variable(name : String)
        Parser.parse_variable(line, name)
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

          if @fast
            data.duration += event.time.to_f if event.t == 'd'
          else
            data.durations << event.time.to_f if event.t == 'd'
          end

          next if @fast

          if event.section == "gc"
            if event.action == "malloc"
              if size = event.variable("size")
                data.sizes << size.to_i
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

require "colorize"

module Crystal
  module Tracing
    class Values(T)
      delegate :size, :sum, :min, :max, to: @values

      def initialize
        @values = [] of T
      end

      def <<(value)
        @values << T.new(value)
      end

      def average
        if @values.empty?
          T.new(0)
        else
          @values.sum / @values.size
        end
      end

      def stddev(mean)
        zero = T.new(0)

        if @values.empty?
          zero
        else
          variance = @values.reduce(zero) { |a, e| a + ((e - mean) ** 2) } / @values.size
          Math.sqrt(variance)
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
        humanize io, mean = average
        io << " ±"
        humanize io, stddev(mean)
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

    class Data
      property events : Int64
      getter values : Hash(Symbol, Values(Float64))

      def initialize
        @events = 0_i64
        @values = {} of Symbol => Values(Float64)
      end

      def duration
        @duration ||= Durations.new
      end

      def sizes
        @sizes ||= Sizes.new
      end

      def each(&)
        yield :events, @events

        if duration = @duration
          yield :duration, duration
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
        @stdin = STDIN,
        @stdout = STDOUT,
        @stderr = STDERR)
      end

      def run
        stats = Section.new do |h, k|
          h[k] = Action.new do |h, k|
            h[k] = Data.new
          end
        end

        each_event do |section, action, t, time, variables|
          data = stats[section][action]
          data.events += 1
          data.duration << time.to_f if t == "d"

          if section == "gc"
            if action == "malloc"
              if variables =~ /\bsize=(\d+)\s*/
                data.sizes << $1.to_i
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

      PARSE_TRACE_RE = /^(\w+) ([-_:\w]+) ([td])=(\d+\.\d+)\s*(.+)$/

      private def each_event(&)
        open_trace_file do |input|
          while line = input.gets(chomp: true)
            if line =~ PARSE_TRACE_RE
              yield $1, $2, $3, $4, $5
            elsif @path != "-"
              @stderr.print "WARN: invalid trace '#{line}'\n"
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

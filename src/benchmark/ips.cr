module Benchmark
  # Benchmark IPS calculates the number of iterations per second for a given
  # block of code. The strategy is to use two stages: a warmup stage and a
  # calculation stage.
  #
  # The warmup phase defaults to 2 seconds. During this stage we figure out how
  # many cycles are needed to run the block for roughly 100ms, and record it.
  #
  # The calculation defaults to 5 seconds. During this stage we run the block
  # in sets of the size calculated in the warmup stage. The measurements for
  # those sets are then used to calculate the mean and standard deviation,
  # which are then reported. Additionally we compare the means to that of the
  # fastest.
  module IPS
    class Job
      # List of all entries in the benchmark.
      # After `#execute`, these are populated with the resulting statistics.
      property items : Array(Entry)

      @warmup_time : Time::Span
      @calculation_time : Time::Span

      def initialize(calculation = 5, warmup = 2, interactive = STDOUT.tty?)
        @interactive = !!interactive
        @warmup_time = warmup.seconds
        @calculation_time = calculation.seconds
        @items = [] of Entry
      end

      # Adds code to be benchmarked
      def report(label = "", &action) : Benchmark::IPS::Entry
        item = Entry.new(label, action)
        @items << item
        item
      end

      def execute : Nil
        run_warmup
        run_calculation
        run_comparison
      end

      def report : Nil
        max_label = ran_items.max_of &.label.size
        max_compare = ran_items.max_of &.human_compare.size
        max_bytes_per_op = ran_items.max_of &.bytes_per_op.humanize(base: 1024).size

        ran_items.each do |item|
          printf "%s %s (%s) (±%5.2f%%)  %sB/op  %s\n",
            item.label.rjust(max_label),
            item.human_mean,
            item.human_iteration_time,
            item.relative_stddev,
            item.bytes_per_op.humanize(base: 1024).rjust(max_bytes_per_op),
            item.human_compare.rjust(max_compare)
        end
      end

      # The warmup stage gathers information about the items that is later used
      # in the calculation stage
      private def run_warmup
        @items.each do |item|
          GC.collect

          count = 0
          elapsed = Time.measure do
            target = Time.monotonic + @warmup_time

            while Time.monotonic < target
              item.call
              count += 1
            end
          end

          item.set_cycles(elapsed, count)
        end
      end

      private def run_calculation
        @items.each do |item|
          GC.collect

          measurements = [] of Time::Span
          bytes = 0_i64
          cycles = 0_i64

          target = Time.monotonic + @calculation_time

          loop do
            elapsed = nil
            bytes_taken = Benchmark.memory do
              elapsed = Time.measure { item.call_for_100ms }
            end
            bytes += bytes_taken
            cycles += item.cycles
            measurements << elapsed.not_nil!
            break if Time.monotonic >= target
          end

          ips = measurements.map { |m| item.cycles.to_f / m.total_seconds }
          item.calculate_stats(ips)

          item.bytes_per_op = (bytes.to_f / cycles.to_f).round.to_u64

          if @interactive
            run_comparison
            report
            print "\e[#{ran_items.size}A"
          end
        end
      end

      private def ran_items
        @items.select(&.ran?)
      end

      private def run_comparison
        fastest = ran_items.max_by(&.mean)
        ran_items.each do |item|
          item.slower = (fastest.mean / item.mean).to_f
        end
      end
    end

    class Entry
      # Label of the benchmark
      property label : String

      # Code to be benchmarked
      property action : ->

      # Number of cycles needed to run `action` for approximately 100ms.
      # Calculated during the warmup stage
      property! cycles : Int32

      # Number of 100ms runs during the calculation stage
      property! size : Int32

      # Statistical mean from calculation stage
      property! mean : Float64

      # Statistical variance from calculation stage
      property! variance : Float64

      # Statistical standard deviation from calculation stage
      property! stddev : Float64

      # Relative standard deviation as a percentage
      property! relative_stddev : Float64

      # Multiple slower than the fastest entry
      property! slower : Float64

      # Number of bytes allocated per operation
      property! bytes_per_op : UInt64

      @ran : Bool
      @ran = false

      def initialize(@label : String, @action : ->)
      end

      def ran? : Bool
        @ran
      end

      def call : Nil
        action.call
      end

      def call_for_100ms : Nil
        cycles.times { action.call }
      end

      def set_cycles(duration, iterations) : Nil
        @cycles = (iterations / duration.total_milliseconds * 100).to_i
        @cycles = 1 if cycles <= 0
      end

      def calculate_stats(samples) : Nil
        @ran = true
        @size = samples.size
        @mean = samples.sum.to_f / size.to_f
        @variance = (samples.reduce(0) { |acc, i| acc + ((i - mean) ** 2) }).to_f / size.to_f
        @stddev = Math.sqrt(variance)
        @relative_stddev = 100.0 * (stddev / mean)
      end

      def human_mean : String
        mean.humanize(precision: 2, significant: false, prefixes: Number::SI_PREFIXES_PADDED).rjust(7)
      end

      def human_iteration_time : String
        iteration_time = 1.0 / mean

        iteration_time.humanize(precision: 2, significant: false) do |magnitude, _|
          magnitude = Number.prefix_index(magnitude).clamp(-9..0)
          {magnitude, magnitude == 0 ? "s " : "#{Number.si_prefix(magnitude)}s"}
        end.rjust(8)
      end

      def human_compare : String
        if slower == 1.0
          "fastest"
        else
          sprintf "%5.2f× slower", slower
        end
      end
    end
  end
end

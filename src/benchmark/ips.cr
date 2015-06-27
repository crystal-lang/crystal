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
      # After #execute, these are populated with the resulting statistics.
      property items :: Array(Entry)

      def initialize(calculation = 5, warmup = 2)
        @warmup_time = warmup.seconds
        @calculation_time = calculation.seconds
        @items = [] of Entry
      end

      # Add code to be benchmarked
      def report(label = "", &action)
        item = Entry.new(label, action)
        @items << item
        item
      end

      def execute
        run_warmup
        run_calculation
        run_comparison
      end

      def report
        max_label = @items.max_of &.label.size

        @items.each do |item|
          if item.slower == 1.0
            compare = "      fastest"
          else
            compare = sprintf "%5.2f× slower", item.slower
          end

          printf "%s %8.2f (± %5.2f) %s\n",
            item.label.rjust(max_label),
            item.mean,
            item.stddev,
            compare
        end
      end

      # The warmup stage gathers information about the items that is later used
      # in the calculation stage
      private def run_warmup
        @items.each do |item|
          GC.collect

          before = Time.now
          target = Time.now + @warmup_time
          count = 0

          while Time.now < target
            item.call
            count += 1
          end

          after = Time.now

          item.set_cycles(after-before, count)
        end
      end

      private def run_calculation
        @items.each do |item|
          GC.collect

          measurements = [] of TimeSpan
          target = Time.now + @calculation_time


          begin
            before = Time.now
            item.call_for_100ms
            after = Time.now

            measurements << after-before
          end while Time.now < target

          final_time = Time.now

          ips = measurements.map { |m| item.cycles.to_f / m.total_seconds }
          item.calculate_stats(ips)# = Stats.new(ips)
        end
      end

      private def run_comparison
        fastest = @items.max_by { |i| i.mean }
        @items.each do |item|
          item.slower = (fastest.mean / item.mean).to_f
        end
      end
    end

    class Entry
      # Label of the benchmark
      property label  :: String

      # Code to be benchmarked
      property action :: ->

      # Number of cycles needed to run for approx 100ms
      # Calculated during the warmup stage
      property! cycles :: Int

      # Number of 100ms runs during the calculation stage
      property! size :: Int

      # Statistcal mean from calculation stage
      property! mean :: Float

      # Statistcal variance from calculation stage
      property! variance :: Float

      # Statistcal standard deviation from calculation stage
      property! stddev :: Float

      # Multiple slower than the fastest entry
      property! slower :: Float

      def initialize(@label, @action) end

      def call
        action.call
      end

      def call_for_100ms
        cycles.times { action.call }
      end

      def set_cycles(duration, iterations)
        @cycles = (iterations / duration.total_milliseconds * 100).to_i
        @cycles = 1 if cycles <= 0
      end

      def calculate_stats(samples)
        @size = samples.size
        @mean = samples.sum.to_f / size.to_f
        @variance = (samples.inject(0) { |acc, i| acc + ((i - mean) ** 2) }).to_f / size.to_f
        @stddev = Math.sqrt(variance)
      end
    end
  end
end

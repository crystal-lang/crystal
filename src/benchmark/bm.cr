module Benchmark
  module BM
    # A data object, representing the times associated with a benchmark measurement.
    class Tms
      # User CPU time
      getter utime : Float64

      # System CPU time
      getter stime : Float64

      # User CPU time of children
      getter cutime : Float64

      # System CPU time of children
      getter cstime : Float64

      # Elapsed real time
      getter real : Float64

      # The label associated with this measure
      getter label : String

      # :nodoc:
      def initialize(@utime, @stime, @cutime, @cstime, @real, @label)
      end

      # Total time, that is utime + stime + cutime + cstime
      def total
        utime + stime + cutime + cstime
      end

      # Prints *utime*, *stime*, *total* and *real* to the given IO.
      def to_s(io : IO)
        io.printf "  %.6f   %.6f   %.6f (  %.6f)", utime, stime, total, real
      end
    end

    # Yielded by `Benchmark#bm`, use `#report` to report benchmarks.
    class Job
      # :nodoc:
      def initialize
        @reports = [] of {String, ->}
        @label_width = 0
      end

      # Reports a single benchmark unit.
      def report(label = " ", &block)
        @label_width = label.size if label.size > @label_width
        @reports << {label, block}
      end

      # :nodoc:
      def execute
        if @label_width > 0
          print " " * @label_width
        end
        puts "       user     system      total        real"

        @reports.each do |report|
          label, block = report
          print label
          diff = @label_width - label.size + 1
          if diff > 0
            print " " * diff
          end
          print Benchmark.measure(label, &block)
          puts
        end
      end
    end
  end
end

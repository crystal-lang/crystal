# The Benchmark module provides methods for benchmarking Crystal code, giving
# detailed reports on the time taken for each task.
#
# ### Measure the time to construct the string given by the expression: `"a"*1_000_000_000`
#
# ```
# require "benchmark"
#
# puts Benchmark.measure { "a"*1_000_000_000 }
# ```
#
# This generates the following output:
#
# ```text
#  0.190000   0.220000   0.410000 (  0.420185)
# ```
#
# This report shows the user CPU time, system CPU time, the sum of
# the user and system CPU times, and the elapsed real time. The unit
# of time is seconds.
#
# ### Do some experiments sequentially using the `#bm` method:
#
# ```
# require "benchmark"
#
# n = 5000000
# Benchmark.bm do |x|
#  x.report("times:") { n.times do ; a = "1"; end }
#  x.report("upto:") { 1.upto(n) do ; a = "1"; end }
# end
# ```
#
# The result:
#
# ```text
#            user     system      total        real
# times:   0.010000   0.000000   0.010000 (  0.008976)
# upto:    0.010000   0.000000   0.010000 (  0.010466)
# ```
#
# Make sure to always benchmark code by compiling with the `--release` flag.
module Benchmark
  extend self

  # A data object, representing the times associated with a benchmark measurement.
  class Tms
    # User CPU time
    getter utime

    # System CPU time
    getter stime

    # User CPU time of children
    getter cutime

    # System CPU time of children
    getter cstime

    # Elapsed real time
    getter real

    # The label associated with this measure
    getter label

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
      @label_width = label.length if label.length > @label_width
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
        diff = @label_width - label.length + 1
        if diff > 0
          print " " * diff
        end
        print Benchmark.measure(label, &block)
        puts
      end
    end
  end

  # Returns the time used to execute the given block.
  def measure(label = "") : Tms
    t0, r0 = Process.times, Time.now
    yield
    t1, r1 = Process.times, Time.now
    Tms.new(t1.utime  - t0.utime,
                     t1.stime  - t0.stime,
                     t1.cutime - t0.cutime,
                     t1.cstime - t0.cstime,
                     (r1.ticks - r0.ticks).to_f / TimeSpan::TicksPerSecond,
                     label)
  end

  # Returns the elapsed real time used to execute the given block.
  #
  # ```
  # Benchmark.realtime { "a" * 100_000 } #=> 00:00:00.0005840
  # ```
  def realtime : TimeSpan
    r0 = Time.now
    yield
    Time.now - r0
  end

  # Main interface of the `Benchmark` module. Yields a `Job` to which
  # one can report the benchmarks. See the module's description.
  def bm
    report = Job.new
    yield report
    report.execute
    report
  end
end

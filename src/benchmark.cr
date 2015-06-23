# A Performance Benchmarking Library
# Overview
#
# The Benchmark module provides methods for benchmarking Crystal code, giving
# detailed reports on the time taken for each task.
#
# * Measure the time to construct the string given by the expression
# ```
# "a"*1_000_000_000
# ```
# 
# ```
# require "benchmark"
#
# puts Benchmark.measure { "a"*1_000_000_000 }
# ```
#
# This generates the following output:
# 
#  0.190000   0.220000   0.410000 (  0.420185)
# 
# This report shows the user CPU time, system CPU time, the sum of
# the user and system CPU times, and the elapsed real time. The unit
# of time is seconds.
#
# * Do some experiments sequentially using the #bm method:
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
#            user     system      total        real
# times:   0.010000   0.000000   0.010000 (  0.008976)
# upto:    0.010000   0.000000   0.010000 (  0.010466)
#
# Note: By default the generated executables are not fully optimized. To turn optimizations on during your benchmarks, use the --release flag
# $ crystal build some_program.cr --release
# 

module Benchmark
  extend self

  # :nodoc:
  class Tms
    getter utime
    getter stime
    getter cutime
    getter cstime
    getter real
    getter label

    def initialize(@utime, @stime, @cutime, @cstime, @real, @label)
    end

    def total
      utime + stime + cutime + cstime
    end

    def to_s(io : IO)
      io.printf "  %.6f   %.6f   %.6f (  %.6f)", utime, stime, total, real
    end
  end

  # :nodoc:
  class Report
    def initialize
      @reports = [] of {String, ->}
      @label_width = 0
    end

    def report(label = " ", &block)
      @label_width = label.length if label.length > @label_width
      @reports << {label, block}
    end

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

  def measure(label = "")
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

  def realtime
    r0 = Time.now
    yield
    Time.now - r0
  end

  def bm
    report = Report.new
    yield report
    report.execute
    report
  end
end

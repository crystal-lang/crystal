require "./benchmark/**"

# The Benchmark module provides methods for benchmarking Crystal code, giving
# detailed reports on the time taken for each task.
#
# ### Measure the number of iterations per second of each task
#
# ```
# require "benchmark"
#
# Benchmark.ips do |x|
#   x.report("short sleep") { sleep 0.01 }
#   x.report("shorter sleep") { sleep 0.001 }
# end
# ```
#
# This generates the following output showing the mean iterations per second,
# the mean times per iteration, the standard deviation relative to the mean, and a comparison:
#
# ```text
#   short sleep   88.7  ( 11.27ms) (± 3.33%)  8.90× slower
# shorter sleep  789.7  (  1.27ms) (± 3.02%)       fastest
# ```
#
# `Benchmark::IPS` defaults to 2 seconds of warmup time and 5 seconds of
# calculation time. This can be configured:
#
# ```
# Benchmark.ips(warmup: 4, calculation: 10) do |x|
#   x.report("sleep") { sleep 0.01 }
# end
# ```
#
# Make sure to always benchmark code by compiling with the `--release` flag.
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
#   x.report("times:") do
#     n.times do
#       a = "1"
#     end
#   end
#   x.report("upto:") do
#     1.upto(n) do
#       a = "1"
#     end
#   end
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

  # Main interface of the `Benchmark` module. Yields a `Job` to which
  # one can report the benchmarks. See the module's description.
  def bm
    {% if !flag?(:release) %}
      puts "Warning: benchmarking without the `--release` flag won't yield useful results"
    {% end %}

    report = BM::Job.new
    yield report
    report.execute
    report
  end

  # Instruction per second interface of the `Benchmark` module. Yields a `Job`
  # to which one can report the benchmarks. See the module's description.
  #
  # The optional parameters *calculation* and *warmup* set the duration of
  # those stages in seconds. For more detail on these stages see
  # `Benchmark::IPS`. When the *interactive* parameter is `true`, results are
  # displayed and updated as they are calculated, otherwise all at once.
  def ips(calculation = 5, warmup = 2, interactive = STDOUT.tty?)
    {% if !flag?(:release) %}
      puts "Warning: benchmarking without the `--release` flag won't yield useful results"
    {% end %}

    job = IPS::Job.new(calculation, warmup, interactive)
    yield job
    job.execute
    job.report
    job
  end

  # Returns the time used to execute the given block.
  def measure(label = "") : BM::Tms
    t0, r0 = Process.times, Time.now
    yield
    t1, r1 = Process.times, Time.now
    BM::Tms.new(t1.utime - t0.utime,
      t1.stime - t0.stime,
      t1.cutime - t0.cutime,
      t1.cstime - t0.cstime,
      (r1.ticks - r0.ticks).to_f / Time::Span::TicksPerSecond,
      label)
  end

  # Returns the elapsed real time used to execute the given block.
  #
  # ```
  # Benchmark.realtime { "a" * 100_000 } # => 00:00:00.0005840
  # ```
  def realtime : Time::Span
    r0 = Time.now
    yield
    Time.now - r0
  end
end

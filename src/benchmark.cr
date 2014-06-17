module Benchmark
  extend self

  class Tms
    getter utime
    getter stime
    getter cutime
    getter cstime
    getter real
    getter label

    def initialize(@utime = 0.0, @stime = 0.0, @cutime = 0.0, @cstime = 0.0, @real = 0.0, @label = "")
    end

    def total
      utime + stime + cutime + cstime
    end

    def to_s
      String.new_with_capacity(50) do |buffer|
        C.sprintf(buffer, "  %.6f   %.6f   %.6f (  %.6f)", utime, stime, total, real)
      end
    end
  end

  struct Report
    def initialize(@label_width)
    end

    def report(label = " ")
      print label
      diff = @label_width - label.length + 1
      if diff > 0
        print " " * diff
      end
      print Benchmark.measure(label) { yield }
      puts
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
                     r1.to_f - r0.to_f,
                     label)
  end

  def realtime
    r0 = Time.now
    yield
    Time.now - r0
  end

  def bm(label_width = 0)
    if label_width > 0
      print " " * label_width
    end
    puts "       user     system      total        real"
    report = Report.new(label_width)
    yield report
    report
  end
end

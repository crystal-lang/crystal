require "spec"
require "benchmark"

# Make sure this compiles (#2578)
typeof(begin
  Benchmark.bm do |b|
    b.report("Here") { puts "Yes" }
  end
end)

describe Benchmark::IPS::Job do
  it "works in general / integration test" do
    # test several things to avoid running a benchmark over and over again in
    # the specs
    j = Benchmark::IPS::Job.new(0.001, 0.001, interactive: false)
    a = j.report("a") { sleep 0.001 }
    b = j.report("b") { sleep 0.002 }

    j.execute

    # the mean should be calculated
    a.mean.should be > 10

    # one of the reports should be normalized to the fastest but do to the
    # timer precision sleep 0.001 may not always be faster than 0.002 so we
    # don't care which
    first, second = [a.slower, b.slower].sort
    first.should eq(1)
    second.should be > 1
  end
end

private def create_entry
  Benchmark::IPS::Entry.new("label", ->{ 1 + 1 })
end

describe Benchmark::IPS::Entry, "#set_cycles" do
  it "sets the number of cycles needed to make 100ms" do
    e = create_entry
    e.set_cycles(2.seconds, 100)
    e.cycles.should eq(5)

    e.set_cycles(100.milliseconds, 1)
    e.cycles.should eq(1)
  end

  it "sets the cycles to 1 no matter what" do
    e = create_entry
    e.set_cycles(2.seconds, 1)
    e.cycles.should eq(1)
  end
end

describe Benchmark::IPS::Entry, "#calculate_stats" do
  it "correctly calculates basic stats" do
    e = create_entry
    e.calculate_stats([2, 4, 4, 4, 5, 5, 7, 9])

    e.size.should eq(8)
    e.mean.should eq(5.0)
    e.variance.should eq(4.0)
    e.stddev.should eq(2.0)
  end
end

private def h_mean(mean)
  create_entry.tap { |e| e.mean = mean }.human_mean
end

describe Benchmark::IPS::Entry, "#human_mean" do
  it { h_mean(0.01234567890123).should eq(" 12.35m") }
  it { h_mean(0.12345678901234).should eq("123.46m") }

  it { h_mean(1.23456789012345).should eq("  1.23 ") }
  it { h_mean(12.3456789012345).should eq(" 12.35 ") }
  it { h_mean(123.456789012345).should eq("123.46 ") }

  it { h_mean(1234.56789012345).should eq("  1.23k") }
  it { h_mean(12345.6789012345).should eq(" 12.35k") }
  it { h_mean(123456.789012345).should eq("123.46k") }

  it { h_mean(1234567.89012345).should eq("  1.23M") }
  it { h_mean(12345678.9012345).should eq(" 12.35M") }
  it { h_mean(123456789.012345).should eq("123.46M") }

  it { h_mean(1234567890.12345).should eq("  1.23G") }
  it { h_mean(12345678901.2345).should eq(" 12.35G") }
  it { h_mean(123456789012.345).should eq("123.46G") }
end

private def h_ips(seconds)
  mean = 1.0 / seconds
  create_entry.tap { |e| e.mean = mean }.human_iteration_time
end

describe Benchmark::IPS::Entry, "#human_iteration_time" do
  it { h_ips(1234.567_890_123).should eq("1,234.57s ") }
  it { h_ips(123.456_789_012_3).should eq("123.46s ") }
  it { h_ips(12.345_678_901_23).should eq(" 12.35s ") }
  it { h_ips(1.234_567_890_123).should eq("  1.23s ") }

  it { h_ips(0.123_456_789_012).should eq("123.46ms") }
  it { h_ips(0.012_345_678_901).should eq(" 12.35ms") }
  it { h_ips(0.001_234_567_890).should eq("  1.23ms") }

  it { h_ips(0.000_123_456_789).should eq("123.46µs") }
  it { h_ips(0.000_012_345_678).should eq(" 12.35µs") }
  it { h_ips(0.000_001_234_567).should eq("  1.23µs") }

  it { h_ips(0.000_000_123_456).should eq("123.46ns") }
  it { h_ips(0.000_000_012_345).should eq(" 12.34ns") }
  it { h_ips(0.000_000_001_234).should eq("  1.23ns") }
  it { h_ips(0.000_000_000_123).should eq("  0.12ns") }
end

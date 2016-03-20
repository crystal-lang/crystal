require "spec"
require "benchmark"

describe Benchmark::IPS::Job do
  it "generally works" do
    # test several things to avoid running a benchmark over and over again in
    # the specs
    j = Benchmark::IPS::Job.new(0.001, 0.001, interactive: false)
    a = j.report("a") { sleep 0.001 }
    b = j.report("b") { sleep 0.002 }

    j.execute

    # the mean should be calculated
    a.mean.should be > 10

    # one of the reports should be normalized to the fastest
    a.slower.should eq(1)
    b.slower.should be > 1
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
  it "correctly caculates basic stats" do
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
  assert { h_mean(0.12345678901234).should eq("  0.12 ") }

  assert { h_mean(1.23456789012345).should eq("  1.23 ") }
  assert { h_mean(12.3456789012345).should eq(" 12.35 ") }
  assert { h_mean(123.456789012345).should eq("123.46 ") }

  assert { h_mean(1234.56789012345).should eq("  1.23k") }
  assert { h_mean(12345.6789012345).should eq(" 12.35k") }
  assert { h_mean(123456.789012345).should eq("123.46k") }

  assert { h_mean(1234567.89012345).should eq("  1.23M") }
  assert { h_mean(12345678.9012345).should eq(" 12.35M") }
  assert { h_mean(123456789.012345).should eq("123.46M") }

  assert { h_mean(1234567890.12345).should eq("  1.23G") }
  assert { h_mean(12345678901.2345).should eq(" 12.35G") }
  assert { h_mean(123456789012.345).should eq("123.46G") }
end

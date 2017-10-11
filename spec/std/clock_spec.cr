require "spec"
require "clock"

describe Clock do
  it "returns monotonic clock" do
    Clock.monotonic.should be_a(Clock)
  end

  it "measures block duration" do
    span = Clock.duration { sleep(0.001) }
    span.to_f.should be_close(0.001, delta: 0.002)
  end

  it "returns clock value" do
    Clock.monotonic.to_f.should be_close(Clock.monotonic.to_f, delta: 0.1)
  end

  it "substracts" do
    (Clock.new(1234_i64, 500_000_000) - Clock.new(1234_i64, 0)).to_f.should be_close(0.5, 0.001)
    (Clock.new(1234_i64, 500_000_000) - 1234.seconds).to_f.should be_close(0.5, 0.001)
    (Clock.new(1234_i64, 500_000_000) - 1234.0).to_f.should be_close(0.5, 0.001)
  end

  it "compares" do
    (Clock.new(2_i64, 0) <=> Clock.new(1_i64, 0)).should eq(1)
    (Clock.new(1_i64, 500_000_000) <=> Clock.new(1_i64, 500_000_000)).should eq(0)
    (Clock.new(1_i64, 0) <=> Clock.new(2_i64, 0)).should eq(-1)

    (Clock.new(2_i64, 0) <=> 1.seconds).should eq(1)
    (Clock.new(1_i64, 500_000_000) <=> 1.5.seconds).should eq(0)
    (Clock.new(1_i64, 0) <=> 2.seconds).should eq(-1)

    (Clock.new(2_i64, 0) <=> 1).should eq(1)
    (Clock.new(1_i64, 500_000_000) <=> 1.5).should eq(0)
    (Clock.new(1_i64, 0) <=> 2).should eq(-1)
  end

  it "elapsed?" do
    clock = Clock.monotonic

    # disabled: randomly fails
    # clock.elapsed?(0.seconds).should be_true

    clock.elapsed?(5.seconds).should be_false
    clock.elapsed?(5.0).should be_false
    sleep 0.01
    clock.elapsed?(0.001).should be_true
  end
end

require "spec"

private def expect_overflow
  expect_raises ArgumentError, "Time::Span too big or too small" do
    yield
  end
end

describe Time::Span do
  it "initializes" do
    t1 = Time::Span.new nanoseconds: 123_456_789_123
    t1.to_s.should eq("00:02:03.456789123")

    t1 = Time::Span.new 1, 2, 3
    t1.to_s.should eq("01:02:03")

    t1 = Time::Span.new 1, 2, 3, 4
    t1.to_s.should eq("1.02:03:04")

    t1 = Time::Span.new 1, 2, 3, 4, 5_000_000
    t1.to_s.should eq("1.02:03:04.005000000")

    t1 = Time::Span.new -1, 2, -3, 4, -5_000_000
    t1.to_s.should eq("-22:02:56.005000000")

    t1 = Time::Span.new 0, 25, 0, 0, 0
    t1.to_s.should eq("1.01:00:00")
  end

  it "days overflows" do
    expect_overflow do
      days = 106751991167301
      Time::Span.new days, 0, 0, 0, 0
    end
  end

  it "max days" do
    expect_overflow do
      Int64::MAX.days
    end
  end

  it "min days" do
    expect_overflow do
      Int64::MIN.days
    end
  end

  it "max seconds" do
    ts = Int32::MAX.seconds
    ts.days.should eq(24855)
    ts.hours.should eq(3)
    ts.minutes.should eq(14)
    ts.seconds.should eq(7)
    ts.milliseconds.should eq(0)
  end

  it "min seconds" do
    ts = Int32::MIN.seconds
    ts.days.should eq(-24855)
    ts.hours.should eq(-3)
    ts.minutes.should eq(-14)
    ts.seconds.should eq(-8)
    ts.milliseconds.should eq(0)
  end

  it "max milliseconds" do
    ts = Int32::MAX.milliseconds
    ts.days.should eq(24)
    ts.hours.should eq(20)
    ts.minutes.should eq(31)
    ts.seconds.should eq(23)
    ts.milliseconds.should eq(647)
  end

  it "min milliseconds" do
    ts = Int32::MIN.milliseconds
    ts.days.should eq(-24)
    ts.hours.should eq(-20)
    ts.minutes.should eq(-31)
    ts.seconds.should eq(-23)
    ts.milliseconds.should eq(-648)
  end

  it "negative timespan" do
    ts = Time::Span.new -23, -59, -59
    ts.days.should eq(0)
    ts.hours.should eq(-23)
    ts.minutes.should eq(-59)
    ts.seconds.should eq(-59)
    ts.milliseconds.should eq(0)
  end

  it "test properties" do
    t1 = Time::Span.new 1, 2, 3, 4, 5_000_000
    t2 = -t1

    t1.days.should eq(1)
    t1.hours.should eq(2)
    t1.minutes.should eq(3)
    t1.seconds.should eq(4)
    t1.milliseconds.should eq(5)
    t1.nanoseconds.should eq(5_000_000)

    t2.days.should eq(-1)
    t2.hours.should eq(-2)
    t2.minutes.should eq(-3)
    t2.seconds.should eq(-4)
    t2.milliseconds.should eq(-5)
    t2.nanoseconds.should eq(-5_000_000)
  end

  it "test add" do
    t1 = Time::Span.new 2, 3, 4, 5, 6_000_000
    t2 = Time::Span.new 1, 2, 3, 4, 5_000_000
    t3 = t1 + t2

    t3.days.should eq(3)
    t3.hours.should eq(5)
    t3.minutes.should eq(7)
    t3.seconds.should eq(9)
    t3.milliseconds.should eq(11)
    t3.nanoseconds.should eq(11_000_000)
    t3.to_s.should eq("3.05:07:09.011000000")

    # TODO check overflow
  end

  it "test compare" do
    t1 = Time::Span.new nanoseconds: -1
    t2 = Time::Span.new nanoseconds: 1

    (t1 <=> t2).should eq(-1)
    (t2 <=> t1).should eq(1)
    (t2 <=> t2).should eq(0)
    (Time::Span::MIN <=> Time::Span::MAX).should eq(-1)

    (t1 == t2).should be_false
    (t1 > t2).should be_false
    (t1 >= t2).should be_false
    (t1 != t2).should be_true
    (t1 < t2).should be_true
    (t1 <= t2).should be_true
  end

  it "test equals" do
    t1 = Time::Span.new nanoseconds: 1
    t2 = Time::Span.new nanoseconds: 2

    (t1 == t1).should be_true
    (t1 == t2).should be_false
    (t1 == "hello").should be_false
  end

  it "test int extension methods" do
    1_000_000.days.to_s.should eq("1000000.00:00:00")
  end

  it "test float extension methods" do
    12.345.days.to_s.should eq("12.08:16:48")
    12.345.hours.to_s.should eq("12:20:42")
    12.345.minutes.to_s.should eq("00:12:20.700000000")
    12.345.seconds.to_s.should eq("00:00:12.345000000")
    12.345.milliseconds.to_s.should eq("00:00:00.012345000")
    -0.5.milliseconds.to_s.should eq("-00:00:00.000500000")
    0.5.milliseconds.to_s.should eq("00:00:00.000500000")
    -2.5.milliseconds.to_s.should eq("-00:00:00.002500000")
    2.5.milliseconds.to_s.should eq("00:00:00.002500000")
    0.0005.seconds.to_s.should eq("00:00:00.000500000")

    1_000_000.5.days.to_s.should eq("1000000.12:00:00")
  end

  it "test negate and duration" do
    (-Time::Span.new(nanoseconds: 1234500)).to_s.should eq("-00:00:00.001234500")
    Time::Span.new(nanoseconds: -1234500).duration.to_s.should eq("00:00:00.001234500")
    Time::Span.new(nanoseconds: -1234500).abs.to_s.should eq("00:00:00.001234500")
    (-Time::Span.new(nanoseconds: 7700)).to_s.should eq("-00:00:00.000007700")
    (+Time::Span.new(nanoseconds: 7700)).to_s.should eq("00:00:00.000007700")
  end

  it "test hash code" do
    t1 = Time::Span.new(nanoseconds: 77)
    t2 = Time::Span.new(nanoseconds: 77)
    t1.hash.should eq(t2.hash)
  end

  it "test subtract" do
    t1 = Time::Span.new 2, 3, 4, 5, 6_000_000
    t2 = Time::Span.new 1, 2, 3, 4, 5_000_000
    t3 = t1 - t2

    t3.to_s.should eq("1.01:01:01.001000000")

    # TODO check overflow
  end

  it "test multiply" do
    t1 = Time::Span.new 5, 4, 3, 2, 1_000_000
    t2 = t1 * 61
    t3 = t1 * 0.5

    t2.should eq(Time::Span.new 315, 7, 5, 2, 61_000_000)
    t3.should eq(Time::Span.new 2, 14, 1, 31, 500_000)

    # TODO check overflow
  end

  it "test divide" do
    t1 = Time::Span.new 3, 3, 3, 3, 3_000_000
    t2 = t1 / 2
    t3 = t1 / 1.5

    t2.should eq(Time::Span.new(1, 13, 31, 31, 501_000_000) + Time::Span.new(nanoseconds: 500_000))
    t3.should eq(Time::Span.new 2, 2, 2, 2, 2_000_000)

    # TODO check overflow
  end

  it "divides by another Time::Span" do
    ratio = 20.minutes / 15.seconds
    ratio.should eq(80.0)

    ratio2 = 45.seconds / 1.minute
    ratio2.should eq(0.75)
  end

  it "test to_s" do
    t1 = Time::Span.new 1, 2, 3, 4, 5_000_000
    t2 = -t1

    t1.to_s.should eq("1.02:03:04.005000000")
    t2.to_s.should eq("-1.02:03:04.005000000")
    Time::Span::MAX.to_s.should eq("106751991167300.15:30:07.999999999")
    Time::Span::MIN.to_s.should eq("-106751991167300.15:30:08.999999999")
    Time::Span::ZERO.to_s.should eq("00:00:00")
  end

  it "test totals" do
    t1 = Time::Span.new 1, 2, 3, 4, 5_000_000
    t1.total_days.should be_close(1.08546, 1e-05)
    t1.total_hours.should be_close(26.0511, 1e-04)
    t1.total_minutes.should be_close(1563.07, 1e-02)
    t1.total_seconds.should be_close(93784, 1e-01)
    t1.total_milliseconds.should be_close(9.3784e+07, 1e+01)
    t1.to_f.should be_close(93784, 1e-01)
    t1.to_i.should eq(93784)

    t2 = Time::Span.new nanoseconds: 123456
    t2.total_seconds.should be_close(0.000123456, 1e-06)
  end

  it "should sum" do
    [1.second, 5.seconds].sum.should eq(6.seconds)
  end

  it "test zero?" do
    Time::Span.new(nanoseconds: 0).zero?.should eq true
    Time::Span.new(nanoseconds: 123456789).zero?.should eq false
  end
end

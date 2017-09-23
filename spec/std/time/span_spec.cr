require "spec"

private def expect_overflow
  expect_raises ArgumentError, "Time::Span too big or too small" do
    yield
  end
end

describe Time::Span do
  it "initializes" do
    t1 = Time::Span.new 1234567890
    t1.to_s.should eq("00:02:03.4567890")

    t1 = Time::Span.new 1, 2, 3
    t1.to_s.should eq("01:02:03")

    t1 = Time::Span.new 1, 2, 3, 4
    t1.to_s.should eq("1.02:03:04")

    t1 = Time::Span.new 1, 2, 3, 4, 5
    t1.to_s.should eq("1.02:03:04.0050000")

    t1 = Time::Span.new -1, 2, -3, 4, -5
    t1.to_s.should eq("-22:02:56.0050000")

    t1 = Time::Span.new 0, 25, 0, 0, 0
    t1.to_s.should eq("1.01:00:00")
  end

  it "days overflows" do
    expect_overflow do
      days = (Int64::MAX / Time::Span::TicksPerDay).to_i32 + 1
      Time::Span.new days, 0, 0, 0, 0
    end
  end

  it "max days" do
    expect_overflow do
      Int32::MAX.days
    end
  end

  it "min days" do
    expect_overflow do
      Int32::MIN.days
    end
  end

  it "max seconds" do
    ts = Int32::MAX.seconds
    ts.days.should eq(24855)
    ts.hours.should eq(3)
    ts.minutes.should eq(14)
    ts.seconds.should eq(7)
    ts.milliseconds.should eq(0)
    ts.ticks.should eq(21474836470000000)
  end

  it "min seconds" do
    ts = Int32::MIN.seconds
    ts.days.should eq(-24855)
    ts.hours.should eq(-3)
    ts.minutes.should eq(-14)
    ts.seconds.should eq(-8)
    ts.milliseconds.should eq(0)
    ts.ticks.should eq(-21474836480000000)
  end

  it "max milliseconds" do
    ts = Int32::MAX.milliseconds
    ts.days.should eq(24)
    ts.hours.should eq(20)
    ts.minutes.should eq(31)
    ts.seconds.should eq(23)
    ts.milliseconds.should eq(647)
    ts.ticks.should eq(21474836470000)
  end

  it "min milliseconds" do
    ts = Int32::MIN.milliseconds
    ts.days.should eq(-24)
    ts.hours.should eq(-20)
    ts.minutes.should eq(-31)
    ts.seconds.should eq(-23)
    ts.milliseconds.should eq(-648)
    ts.ticks.should eq(-21474836480000)
  end

  it "negative timespan" do
    ts = Time::Span.new -23, -59, -59
    ts.days.should eq(0)
    ts.hours.should eq(-23)
    ts.minutes.should eq(-59)
    ts.seconds.should eq(-59)
    ts.milliseconds.should eq(0)
    ts.ticks.should eq(-863990000000)
  end

  it "test properties" do
    t1 = Time::Span.new 1, 2, 3, 4, 5
    t2 = -t1

    t1.days.should eq(1)
    t1.hours.should eq(2)
    t1.minutes.should eq(3)
    t1.seconds.should eq(4)
    t1.milliseconds.should eq(5)

    t2.days.should eq(-1)
    t2.hours.should eq(-2)
    t2.minutes.should eq(-3)
    t2.seconds.should eq(-4)
    t2.milliseconds.should eq(-5)
  end

  it "test add" do
    t1 = Time::Span.new 2, 3, 4, 5, 6
    t2 = Time::Span.new 1, 2, 3, 4, 5
    t3 = t1 + t2

    t3.days.should eq(3)
    t3.hours.should eq(5)
    t3.minutes.should eq(7)
    t3.seconds.should eq(9)
    t3.milliseconds.should eq(11)
    t3.to_s.should eq("3.05:07:09.0110000")

    # TODO check overflow
  end

  it "test compare" do
    t1 = Time::Span.new -1
    t2 = Time::Span.new 1

    (t1 <=> t2).should eq(-1)
    (t2 <=> t1).should eq(1)
    (t2 <=> t2).should eq(0)
    (Time::Span::MinValue <=> Time::Span::MaxValue).should eq(-1)

    (t1 == t2).should be_false
    (t1 > t2).should be_false
    (t1 >= t2).should be_false
    (t1 != t2).should be_true
    (t1 < t2).should be_true
    (t1 <= t2).should be_true
  end

  it "test equals" do
    t1 = Time::Span.new 1
    t2 = Time::Span.new 2

    (t1 == t1).should be_true
    (t1 == t2).should be_false
    (t1 == "hello").should be_false
  end

  it "test float extension methods" do
    12.345.days.to_s.should eq("12.08:16:48")
    12.345.hours.to_s.should eq("12:20:42")
    12.345.minutes.to_s.should eq("00:12:20.7000000")
    12.345.seconds.to_s.should eq("00:00:12.3450000")
    12.345.milliseconds.to_s.should eq("00:00:00.0120000")
    -0.5.milliseconds.to_s.should eq("-00:00:00.0010000")
    0.5.milliseconds.to_s.should eq("00:00:00.0010000")
    -2.5.milliseconds.to_s.should eq("-00:00:00.0030000")
    2.5.milliseconds.to_s.should eq("00:00:00.0030000")
    0.0005.seconds.to_s.should eq("00:00:00.0010000")
  end

  it "test negate and duration" do
    (-Time::Span.new(12345)).to_s.should eq("-00:00:00.0012345")
    Time::Span.new(-12345).duration.to_s.should eq("00:00:00.0012345")
    Time::Span.new(-12345).abs.to_s.should eq("00:00:00.0012345")
    (-Time::Span.new(77)).to_s.should eq("-00:00:00.0000077")
    (+Time::Span.new(77)).to_s.should eq("00:00:00.0000077")
  end

  it "test hash code" do
    t1 = Time::Span.new(77)
    t2 = Time::Span.new(77)
    t1.hash.should eq(t2.hash)
  end

  it "test subtract" do
    t1 = Time::Span.new 2, 3, 4, 5, 6
    t2 = Time::Span.new 1, 2, 3, 4, 5
    t3 = t1 - t2

    t3.to_s.should eq("1.01:01:01.0010000")

    # TODO check overflow
  end

  it "test multiply" do
    t1 = Time::Span.new 5, 4, 3, 2, 1
    t2 = t1 * 61

    t2.should eq(Time::Span.new 315, 7, 5, 2, 61)

    # TODO check overflow
  end

  it "test divide" do
    t1 = Time::Span.new 3, 3, 3, 3, 3
    t2 = t1 / 2

    t2.should eq(Time::Span.new(1, 13, 31, 31, 501) + Time::Span.new(5000))

    # TODO check overflow
  end

  it "divides by another Time::Span" do
    ratio = 20.minutes / 15.seconds
    ratio.should eq(80.0)

    ratio2 = 45.seconds / 1.minute
    ratio2.should eq(0.75)
  end

  it "test to_s" do
    t1 = Time::Span.new 1, 2, 3, 4, 5
    t2 = -t1

    t1.to_s.should eq("1.02:03:04.0050000")
    t2.to_s.should eq("-1.02:03:04.0050000")
    Time::Span::MaxValue.to_s.should eq("10675199.02:48:05.4775807")
    Time::Span::MinValue.to_s.should eq("-10675199.02:48:05.4775808")
    Time::Span::Zero.to_s.should eq("00:00:00")
  end

  it "test totals" do
    t1 = Time::Span.new 1, 2, 3, 4, 5
    t1.total_days.should be_close(1.08546, 1e-05)
    t1.total_hours.should be_close(26.0511, 1e-04)
    t1.total_minutes.should be_close(1563.07, 1e-02)
    t1.total_seconds.should be_close(93784, 1e-01)
    t1.total_milliseconds.should be_close(9.3784e+07, 1e+01)
    t1.to_f.should be_close(93784, 1e-01)
    t1.to_i.should eq(93784)
  end

  it "should sum" do
    [1.second, 5.seconds].sum.should eq(6.seconds)
  end

  it "test zero?" do
    Time::Span.new(0).zero?.should eq true
    Time::Span.new(123456789).zero?.should eq false
  end
end

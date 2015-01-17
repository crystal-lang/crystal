require "spec"

private def expect_overflow
  expect_raises ArgumentError, "TimeSpan too big or too small" do
    yield
  end
end

describe TimeSpan do
  it "initializes" do
    t1 = TimeSpan.new 1234567890
    t1.to_s.should eq("00:02:03.4567890")

    t1 = TimeSpan.new 1, 2, 3
    t1.to_s.should eq("01:02:03")

    t1 = TimeSpan.new 1, 2, 3, 4
    t1.to_s.should eq("1.02:03:04")

    t1 = TimeSpan.new 1, 2, 3, 4, 5
    t1.to_s.should eq("1.02:03:04.0050000")

    t1 = TimeSpan.new -1, 2, -3, 4, -5
    t1.to_s.should eq("-22:02:56.0050000")

    t1 = TimeSpan.new 0, 25, 0, 0, 0
    t1.to_s.should eq("1.01:00:00")
  end

  it "days overflows" do
    expect_overflow do
      days = (Int64::MAX / TimeSpan::TicksPerDay).to_i32 + 1
      TimeSpan.new days, 0, 0, 0, 0
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
    ts = TimeSpan.new -23, -59, -59
    ts.days.should eq(0)
    ts.hours.should eq(-23)
    ts.minutes.should eq(-59)
    ts.seconds.should eq(-59)
    ts.milliseconds.should eq(0)
    ts.ticks.should eq(-863990000000)
  end

  it "test properties" do
    t1 = TimeSpan.new 1, 2, 3, 4, 5
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
    t1 = TimeSpan.new 2, 3, 4, 5, 6
    t2 = TimeSpan.new 1, 2, 3, 4, 5
    t3 = t1 + t2;

    t3.days.should eq(3)
    t3.hours.should eq(5)
    t3.minutes.should eq(7)
    t3.seconds.should eq(9)
    t3.milliseconds.should eq(11)
    t3.to_s.should eq("3.05:07:09.0110000")

    # TODO check overflow
  end

  it "test compare" do
    t1 = TimeSpan.new -1
    t2 = TimeSpan.new 1

    (t1 <=> t2).should eq(-1)
    (t2 <=> t1).should eq(1)
    (t2 <=> t2).should eq(0)
    (TimeSpan::MinValue <=> TimeSpan::MaxValue).should eq(-1)

    (t1 == t2).should be_false
    (t1 > t2).should be_false
    (t1 >= t2).should be_false
    (t1 != t2).should be_true
    (t1 < t2).should be_true
    (t1 <= t2).should be_true
  end

  it "test equals" do
    t1 = TimeSpan.new 1
    t2 = TimeSpan.new 2

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
    (-TimeSpan.new(12345)).to_s.should eq("-00:00:00.0012345")
    TimeSpan.new(-12345).duration.to_s.should eq("00:00:00.0012345")
    TimeSpan.new(-12345).abs.to_s.should eq("00:00:00.0012345")
    (-TimeSpan.new(77)).to_s.should eq("-00:00:00.0000077")
    (+TimeSpan.new(77)).to_s.should eq("00:00:00.0000077")
  end

  it "test hash code" do
    TimeSpan.new(77).hash.should eq(77)
  end

  it "test subtract" do
    t1 = TimeSpan.new 2, 3, 4, 5, 6
    t2 = TimeSpan.new 1, 2, 3, 4, 5
    t3 = t1 - t2

    t3.to_s.should eq("1.01:01:01.0010000")

    # TODO check overflow
  end

  it "test to_s" do
    t1 = TimeSpan.new 1, 2, 3, 4, 5
    t2 = -t1

    t1.to_s.should eq("1.02:03:04.0050000")
    t2.to_s.should eq("-1.02:03:04.0050000")
    TimeSpan::MaxValue.to_s.should eq("10675199.02:48:05.4775807")
    TimeSpan::MinValue.to_s.should eq("-10675199.02:48:05.4775808")
    TimeSpan::Zero.to_s.should eq("00:00:00")
  end

  it "test totals" do
    t1 = TimeSpan.new 1, 2, 3, 4, 5
    t1.total_days.should be_close(1.08546, 1e-05)
    t1.total_hours.should be_close(26.0511, 1e-04)
    t1.total_minutes.should be_close(1563.07, 1e-02)
    t1.total_seconds.should be_close(93784, 1e-01)
    t1.total_milliseconds.should be_close(9.3784e+07, 1e+01)
  end
end

require "spec"

private def expect_overflow
  expect_raises ArgumentError, "TimeSpan too big or too small" do
    yield
  end
end

describe TimeSpan do
  it "initializes" do
    t1 = TimeSpan.new 1234567890
    expect(t1.to_s).to eq("00:02:03.4567890")

    t1 = TimeSpan.new 1, 2, 3
    expect(t1.to_s).to eq("01:02:03")

    t1 = TimeSpan.new 1, 2, 3, 4
    expect(t1.to_s).to eq("1.02:03:04")

    t1 = TimeSpan.new 1, 2, 3, 4, 5
    expect(t1.to_s).to eq("1.02:03:04.0050000")

    t1 = TimeSpan.new -1, 2, -3, 4, -5
    expect(t1.to_s).to eq("-22:02:56.0050000")

    t1 = TimeSpan.new 0, 25, 0, 0, 0
    expect(t1.to_s).to eq("1.01:00:00")
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
    expect(ts.days).to eq(24855)
    expect(ts.hours).to eq(3)
    expect(ts.minutes).to eq(14)
    expect(ts.seconds).to eq(7)
    expect(ts.milliseconds).to eq(0)
    expect(ts.ticks).to eq(21474836470000000)
  end

  it "min seconds" do
    ts = Int32::MIN.seconds
    expect(ts.days).to eq(-24855)
    expect(ts.hours).to eq(-3)
    expect(ts.minutes).to eq(-14)
    expect(ts.seconds).to eq(-8)
    expect(ts.milliseconds).to eq(0)
    expect(ts.ticks).to eq(-21474836480000000)
  end

  it "max milliseconds" do
    ts = Int32::MAX.milliseconds
    expect(ts.days).to eq(24)
    expect(ts.hours).to eq(20)
    expect(ts.minutes).to eq(31)
    expect(ts.seconds).to eq(23)
    expect(ts.milliseconds).to eq(647)
    expect(ts.ticks).to eq(21474836470000)
  end

  it "min milliseconds" do
    ts = Int32::MIN.milliseconds
    expect(ts.days).to eq(-24)
    expect(ts.hours).to eq(-20)
    expect(ts.minutes).to eq(-31)
    expect(ts.seconds).to eq(-23)
    expect(ts.milliseconds).to eq(-648)
    expect(ts.ticks).to eq(-21474836480000)
  end

  it "negative timespan" do
    ts = TimeSpan.new -23, -59, -59
    expect(ts.days).to eq(0)
    expect(ts.hours).to eq(-23)
    expect(ts.minutes).to eq(-59)
    expect(ts.seconds).to eq(-59)
    expect(ts.milliseconds).to eq(0)
    expect(ts.ticks).to eq(-863990000000)
  end

  it "test properties" do
    t1 = TimeSpan.new 1, 2, 3, 4, 5
    t2 = -t1

    expect(t1.days).to eq(1)
    expect(t1.hours).to eq(2)
    expect(t1.minutes).to eq(3)
    expect(t1.seconds).to eq(4)
    expect(t1.milliseconds).to eq(5)

    expect(t2.days).to eq(-1)
    expect(t2.hours).to eq(-2)
    expect(t2.minutes).to eq(-3)
    expect(t2.seconds).to eq(-4)
    expect(t2.milliseconds).to eq(-5)
  end

  it "test add" do
    t1 = TimeSpan.new 2, 3, 4, 5, 6
    t2 = TimeSpan.new 1, 2, 3, 4, 5
    t3 = t1 + t2;

    expect(t3.days).to eq(3)
    expect(t3.hours).to eq(5)
    expect(t3.minutes).to eq(7)
    expect(t3.seconds).to eq(9)
    expect(t3.milliseconds).to eq(11)
    expect(t3.to_s).to eq("3.05:07:09.0110000")

    # TODO check overflow
  end

  it "test compare" do
    t1 = TimeSpan.new -1
    t2 = TimeSpan.new 1

    expect((t1 <=> t2)).to eq(-1)
    expect((t2 <=> t1)).to eq(1)
    expect((t2 <=> t2)).to eq(0)
    expect((TimeSpan::MinValue <=> TimeSpan::MaxValue)).to eq(-1)

    expect((t1 == t2)).to be_false
    expect((t1 > t2)).to be_false
    expect((t1 >= t2)).to be_false
    expect((t1 != t2)).to be_true
    expect((t1 < t2)).to be_true
    expect((t1 <= t2)).to be_true
  end

  it "test equals" do
    t1 = TimeSpan.new 1
    t2 = TimeSpan.new 2

    expect((t1 == t1)).to be_true
    expect((t1 == t2)).to be_false
    expect((t1 == "hello")).to be_false
  end

  it "test float extension methods" do
    expect(12.345.days.to_s).to eq("12.08:16:48")
    expect(12.345.hours.to_s).to eq("12:20:42")
    expect(12.345.minutes.to_s).to eq("00:12:20.7000000")
    expect(12.345.seconds.to_s).to eq("00:00:12.3450000")
    expect(12.345.milliseconds.to_s).to eq("00:00:00.0120000")
    expect(-0.5.milliseconds.to_s).to eq("-00:00:00.0010000")
    expect(0.5.milliseconds.to_s).to eq("00:00:00.0010000")
    expect(-2.5.milliseconds.to_s).to eq("-00:00:00.0030000")
    expect(2.5.milliseconds.to_s).to eq("00:00:00.0030000")
    expect(0.0005.seconds.to_s).to eq("00:00:00.0010000")
  end

  it "test negate and duration" do
    expect((-TimeSpan.new(12345)).to_s).to eq("-00:00:00.0012345")
    expect(TimeSpan.new(-12345).duration.to_s).to eq("00:00:00.0012345")
    expect(TimeSpan.new(-12345).abs.to_s).to eq("00:00:00.0012345")
    expect((-TimeSpan.new(77)).to_s).to eq("-00:00:00.0000077")
    expect((+TimeSpan.new(77)).to_s).to eq("00:00:00.0000077")
  end

  it "test hash code" do
    expect(TimeSpan.new(77).hash).to eq(77)
  end

  it "test subtract" do
    t1 = TimeSpan.new 2, 3, 4, 5, 6
    t2 = TimeSpan.new 1, 2, 3, 4, 5
    t3 = t1 - t2

    expect(t3.to_s).to eq("1.01:01:01.0010000")

    # TODO check overflow
  end

  it "test to_s" do
    t1 = TimeSpan.new 1, 2, 3, 4, 5
    t2 = -t1

    expect(t1.to_s).to eq("1.02:03:04.0050000")
    expect(t2.to_s).to eq("-1.02:03:04.0050000")
    expect(TimeSpan::MaxValue.to_s).to eq("10675199.02:48:05.4775807")
    expect(TimeSpan::MinValue.to_s).to eq("-10675199.02:48:05.4775808")
    expect(TimeSpan::Zero.to_s).to eq("00:00:00")
  end

  it "test totals" do
    t1 = TimeSpan.new 1, 2, 3, 4, 5
    expect(t1.total_days).to be_close(1.08546, 1e-05)
    expect(t1.total_hours).to be_close(26.0511, 1e-04)
    expect(t1.total_minutes).to be_close(1563.07, 1e-02)
    expect(t1.total_seconds).to be_close(93784, 1e-01)
    expect(t1.total_milliseconds).to be_close(9.3784e+07, 1e+01)
    expect(t1.to_f).to be_close(93784, 1e-01)
    expect(t1.to_i).to eq(93784)
  end
end

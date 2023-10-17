require "spec"
require "spec/helpers/iterate"

private def expect_overflow(&)
  expect_raises ArgumentError, "Time::Span too big or too small" do
    yield
  end
end

describe Time::Span do
  it "initializes" do
    t1 = Time::Span.new nanoseconds: 123_456_789_123
    t1.to_s.should eq("00:02:03.456789123")

    t1 = Time::Span.new hours: 1, minutes: 2, seconds: 3
    t1.to_s.should eq("01:02:03")

    t1 = Time::Span.new minutes: 2, seconds: 3
    t1.to_s.should eq("00:02:03")

    t1 = Time::Span.new seconds: 3
    t1.to_s.should eq("00:00:03")

    t1 = Time::Span.new days: 1, hours: 2, minutes: 3, seconds: 4
    t1.to_s.should eq("1.02:03:04")

    t1 = Time::Span.new days: 1, hours: 2, minutes: 3, seconds: 4, nanoseconds: 5_000_000
    t1.to_s.should eq("1.02:03:04.005000000")

    t1 = Time::Span.new days: -1, hours: 2, minutes: -3, seconds: 4, nanoseconds: -5_000_000
    t1.to_s.should eq("-22:02:56.005000000")

    t1 = Time::Span.new hours: 25
    t1.to_s.should eq("1.01:00:00")
  end

  it "initializes with type restrictions" do
    t = Time::Span.new seconds: 1_u8, nanoseconds: 1_u8
    t.should eq(Time::Span.new seconds: 1, nanoseconds: 1)

    t = Time::Span.new seconds: 127_i8, nanoseconds: 1_000_000_000
    t.should eq(Time::Span.new seconds: 128)

    t = Time::Span.new seconds: -128_i8, nanoseconds: -1_000_000_000
    t.should eq(Time::Span.new seconds: -129)

    t = Time::Span.new seconds: 255_u8, nanoseconds: 1_000_000_000
    t.should eq(Time::Span.new seconds: 256)

    t = Time::Span.new seconds: 0_u8, nanoseconds: -1_000_000_000
    t.should eq(Time::Span.new seconds: -1)
  end

  it "initializes with big seconds value" do
    t = Time::Span.new hours: 0, minutes: 0, seconds: 1231231231231
    t.total_seconds.should eq(1231231231231)
  end

  it "days overflows" do
    expect_overflow do
      days = 106751991167301
      Time::Span.new days: days
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
    ts.nanoseconds.should eq(0)
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
    ts = Time::Span.new hours: -23, minutes: -59, seconds: -59
    ts.days.should eq(0)
    ts.hours.should eq(-23)
    ts.minutes.should eq(-59)
    ts.seconds.should eq(-59)
    ts.milliseconds.should eq(0)
  end

  it "test properties" do
    t1 = Time::Span.new days: 1, hours: 2, minutes: 3, seconds: 4, nanoseconds: 5_000_000
    t2 = -t1

    t1.days.should eq(1)
    t1.hours.should eq(2)
    t1.minutes.should eq(3)
    t1.seconds.should eq(4)
    t1.milliseconds.should eq(5)
    t1.microseconds.should eq(5_000)
    t1.nanoseconds.should eq(5_000_000)

    t2.days.should eq(-1)
    t2.hours.should eq(-2)
    t2.minutes.should eq(-3)
    t2.seconds.should eq(-4)
    t2.milliseconds.should eq(-5)
    t2.microseconds.should eq(-5_000)
    t2.nanoseconds.should eq(-5_000_000)
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

  describe "#step" do
    it_iterates "basic", [1.day, 2.days, 3.days, 4.days, 5.days], 1.days.step(to: 5.days, by: 1.day)
  end

  it "test int extension methods" do
    1_000_000.days.to_s.should eq("1000000.00:00:00")
    12.microseconds.to_s.should eq("00:00:00.000012000")
    -12.microseconds.to_s.should eq("-00:00:00.000012000")
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
    -2.5.microseconds.to_s.should eq("-00:00:00.000002500")
    2.5.microseconds.to_s.should eq("00:00:00.000002500")
    0.0005.seconds.to_s.should eq("00:00:00.000500000")

    1_000_000.5.days.to_s.should eq("1000000.12:00:00")
  end

  it "test negate and abs" do
    (-Time::Span.new(nanoseconds: 1234500)).to_s.should eq("-00:00:00.001234500")
    Time::Span.new(nanoseconds: -1234500).abs.to_s.should eq("00:00:00.001234500")
    (-Time::Span.new(nanoseconds: 7700)).to_s.should eq("-00:00:00.000007700")
    (+Time::Span.new(nanoseconds: 7700)).to_s.should eq("00:00:00.000007700")
  end

  it "test hash code" do
    t1 = Time::Span.new(nanoseconds: 77)
    t2 = Time::Span.new(nanoseconds: 77)
    t1.hash.should eq(t2.hash)
  end

  describe "arithmetic" do
    it "#+" do
      t1 = Time::Span.new days: 2, hours: 3, minutes: 4, seconds: 5, nanoseconds: 6_000_000
      t2 = Time::Span.new days: 1, hours: 2, minutes: 3, seconds: 4, nanoseconds: 5_000_000
      t3 = t1 + t2

      t3.days.should eq(3)
      t3.hours.should eq(5)
      t3.minutes.should eq(7)
      t3.seconds.should eq(9)
      t3.milliseconds.should eq(11)
      t3.nanoseconds.should eq(11_000_000)
      t3.to_s.should eq("3.05:07:09.011000000")

      expect_raises(OverflowError) do
        Time::Span::MAX + Time::Span.new(seconds: 1)
      end
      expect_raises(OverflowError) do
        Time::Span.new(seconds: Int64::MAX) + Time::Span.new(seconds: 1)
      end
      (Time::Span.new(nanoseconds: Int64::MAX) + Time::Span.new(nanoseconds: 1)).should eq Time::Span.new days: 106751, hours: 23, minutes: 47, seconds: 16, nanoseconds: 854775808
    end

    it "#-" do
      t1 = Time::Span.new days: 2, hours: 3, minutes: 4, seconds: 5, nanoseconds: 6_000_000
      t2 = Time::Span.new days: 1, hours: 2, minutes: 3, seconds: 4, nanoseconds: 5_000_000
      t3 = t1 - t2

      t3.to_s.should eq("1.01:01:01.001000000")

      expect_raises(OverflowError) do
        Time::Span::MIN - Time::Span.new(seconds: 1)
      end
      expect_raises(OverflowError) do
        Time::Span.new(seconds: Int64::MIN) - Time::Span.new(seconds: 1)
      end
      (Time::Span.new(nanoseconds: Int64::MIN) - Time::Span.new(nanoseconds: 1)).should eq -Time::Span.new days: 106751, hours: 23, minutes: 47, seconds: 16, nanoseconds: 854775809
    end

    it "#*" do
      t1 = Time::Span.new days: 5, hours: 4, minutes: 3, seconds: 2, nanoseconds: 1_000_000
      t2 = t1 * 61
      t3 = t1 * 0.5

      t2.should eq(Time::Span.new days: 315, hours: 7, minutes: 5, seconds: 2, nanoseconds: 61_000_000)
      t3.should eq(Time::Span.new days: 2, hours: 14, minutes: 1, seconds: 31, nanoseconds: 500_000)

      expect_raises(OverflowError) do
        Time::Span::MAX * 2
      end
      t = Time::Span.new(seconds: Int64::MAX // 2 + 1)
      expect_raises(OverflowError) do
        t * 2
      end
      t = Time::Span.new(nanoseconds: Int64::MAX // 2 + 1)
      (t * 2).should eq Time::Span.new days: 106751, hours: 23, minutes: 47, seconds: 16, nanoseconds: 854775808
    end

    it "#/(Number)" do
      t1 = Time::Span.new days: 3, hours: 3, minutes: 3, seconds: 3, nanoseconds: 3_000_000
      t2 = t1 / 2
      t3 = t1 / 1.5

      t2.should eq(Time::Span.new(days: 1, hours: 13, minutes: 31, seconds: 31, nanoseconds: 501_000_000) + Time::Span.new(nanoseconds: 500_000))
      t3.should eq(Time::Span.new days: 2, hours: 2, minutes: 2, seconds: 2, nanoseconds: 2_000_000)

      expect_raises(DivisionByZeroError) do
        Time::Span::MAX / 0
      end
    end

    it "#/(self)" do
      ratio = 20.minutes / 15.seconds
      ratio.should eq(80.0)

      ratio2 = 45.seconds / 1.minute
      ratio2.should eq(0.75)
    end

    it "#sign" do
      Time::Span.new(days: 2).sign.should eq 1
      Time::Span.new(days: -2).sign.should eq -1
      Time::Span.new.sign.should eq 0
      Time::Span.new(nanoseconds: -2).sign.should eq -1
      Time::Span.new(nanoseconds: 2).sign.should eq 1
    end
  end

  it "test to_s" do
    t1 = Time::Span.new days: 1, hours: 2, minutes: 3, seconds: 4, nanoseconds: 5_000_000
    t2 = -t1

    t1.to_s.should eq("1.02:03:04.005000000")
    t2.to_s.should eq("-1.02:03:04.005000000")
    Time::Span::MAX.to_s.should eq("106751991167300.15:30:07.999999999")
    Time::Span::MIN.to_s.should eq("-106751991167300.15:30:08.999999999")
    Time::Span::ZERO.to_s.should eq("00:00:00")
  end

  it "test totals" do
    t1 = Time::Span.new days: 1, hours: 2, minutes: 3, seconds: 4, nanoseconds: 5_000_000
    t1.total_days.should be_close(1.08546, 1e-05)
    t1.total_hours.should be_close(26.0511, 1e-04)
    t1.total_minutes.should be_close(1563.07, 1e-02)
    t1.total_seconds.should be_close(93784, 1e-01)
    t1.total_milliseconds.should be_close(9.3784e+07, 1e+01)
    t1.total_microseconds.should be_close(9.3784e+10, 1e+04)
    t1.total_nanoseconds.should be_close(9.3784e+13, 1e+07)
    t1.to_f.should be_close(93784, 1e-01)
    t1.to_i.should eq(93784)

    t2 = Time::Span.new nanoseconds: 123456
    t2.total_seconds.should be_close(0.000123456, 1e-06)
  end

  it "should sum" do
    [1.second, 5.seconds].sum.should eq(6.seconds)
  end

  it "#zero?" do
    Time::Span.zero.zero?.should be_true
    Time::Span::ZERO.zero?.should be_true
    Time::Span.new(nanoseconds: 123456789).zero?.should be_false
  end

  it "#positive?" do
    Time::Span.new(nanoseconds: 123456789).positive?.should be_true
    Time::Span.zero.positive?.should be_false
    Time::Span.new(nanoseconds: -123456789).positive?.should be_false
  end

  it "#negative?" do
    Time::Span.new(nanoseconds: 123456789).negative?.should be_false
    Time::Span.zero.negative?.should be_false
    Time::Span.new(nanoseconds: -123456789).negative?.should be_true
  end

  it "converts units" do
    1.nanoseconds.should eq(Time::Span.new(nanoseconds: 1))
    1.millisecond.should eq(1_000_000.nanoseconds)
    1.milliseconds.should eq(1_000_000.nanoseconds)
    1.second.should eq(1000.milliseconds)
    1.seconds.should eq(1000.milliseconds)
    1.minute.should eq(60.seconds)
    1.minutes.should eq(60.seconds)
    1.hour.should eq(60.minutes)
    1.hours.should eq(60.minutes)
    1.week.should eq(7.days)
    2.weeks.should eq(14.days)
    1.1.weeks.should eq(7.7.days)
  end
end

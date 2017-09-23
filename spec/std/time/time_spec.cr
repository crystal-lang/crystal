require "spec"

private TimeSpecTicks = [
  631501920000000000_i64, # 25 Feb 2002 - 00:00:00
  631502475130080000_i64, # 25 Feb 2002 - 15:25:13,8
  631502115130080000_i64, # 25 Feb 2002 - 05:25:13,8
]

def Time.expect_invalid
  expect_raises ArgumentError, "Invalid time" do
    yield
  end
end

describe Time do
  it "initialize" do
    t1 = Time.new 2002, 2, 25
    t1.ticks.should eq(TimeSpecTicks[0])

    t2 = Time.new 2002, 2, 25, 15, 25, 13, 8
    t2.ticks.should eq(TimeSpecTicks[1])

    t2.date.ticks.should eq(TimeSpecTicks[0])
    t2.year.should eq(2002)
    t2.month.should eq(2)
    t2.day.should eq(25)
    t2.hour.should eq(15)
    t2.minute.should eq(25)
    t2.second.should eq(13)
    t2.millisecond.should eq(8)

    t3 = Time.new 2002, 2, 25, 5, 25, 13, 8
    t3.ticks.should eq(TimeSpecTicks[2])
  end

  it "initialize max" do
    Time.new(9999, 12, 31, 23, 59, 59, 999).ticks.should eq(3155378975999990000)
  end

  it "initialize millisecond negative" do
    Time.expect_invalid do
      Time.new(9999, 12, 31, 23, 59, 59, -1)
    end
  end

  it "initialize millisecond 1000" do
    Time.expect_invalid do
      Time.new(9999, 12, 31, 23, 59, 59, 1000)
    end
  end

  it "initialize with .epoch" do
    seconds = 1439404155
    time = Time.epoch(seconds)
    time.should eq(Time.new(2015, 8, 12, 18, 29, 15, kind: Time::Kind::Utc))
    time.epoch.should eq(seconds)
  end

  it "initialize with .epoch_ms" do
    milliseconds = 1439404155000
    time = Time.epoch_ms(milliseconds)
    time.should eq(Time.new(2015, 8, 12, 18, 29, 15, kind: Time::Kind::Utc))
    time.epoch_ms.should eq(milliseconds)
  end

  it "clones" do
    time = Time.now
    (time == time.clone).should be_true
  end

  it "fields" do
    Time::MaxValue.ticks.should eq(3155378975999999999)
    Time::MinValue.ticks.should eq(0)
  end

  it "add" do
    t1 = Time.new TimeSpecTicks[1]
    span = Time::Span.new 3, 54, 1
    t2 = t1 + span

    t2.day.should eq(25)
    t2.hour.should eq(19)
    t2.minute.should eq(19)
    t2.second.should eq(14)

    t1.day.should eq(25)
    t1.hour.should eq(15)
    t1.minute.should eq(25)
    t1.second.should eq(13)
  end

  it "add out of range 1" do
    t1 = Time.new TimeSpecTicks[1]

    expect_raises ArgumentError do
      t1 + Time::Span::MaxValue
    end
  end

  it "add out of range 2" do
    t1 = Time.new TimeSpecTicks[1]

    expect_raises ArgumentError do
      t1 + Time::Span::MinValue
    end
  end

  it "add days" do
    t1 = Time.new TimeSpecTicks[1]
    t1 = t1 + 3.days

    t1.day.should eq(28)
    t1.hour.should eq(15)
    t1.minute.should eq(25)
    t1.second.should eq(13)

    t1 = t1 + 1.9.days
    t1.day.should eq(2)
    t1.hour.should eq(13)
    t1.minute.should eq(1)
    t1.second.should eq(13)

    t1 = t1 + 0.2.days
    t1.day.should eq(2)
    t1.hour.should eq(17)
    t1.minute.should eq(49)
    t1.second.should eq(13)
  end

  it "add days out of range 1" do
    t1 = Time.new TimeSpecTicks[1]
    expect_raises ArgumentError do
      t1 + 10000000.days
    end
  end

  it "add days out of range 2" do
    t1 = Time.new TimeSpecTicks[1]
    expect_raises ArgumentError do
      t1 - 10000000.days
    end
  end

  it "add months" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t2 = t + 1.month
    t2.to_s.should eq("2014-11-30 21:18:13")

    t2 = t + 1.months
    t2.to_s.should eq("2014-11-30 21:18:13")

    t = Time.new 2014, 10, 31, 21, 18, 13
    t2 = t + 1.month
    t2.to_s.should eq("2014-11-30 21:18:13")

    t = Time.new 2014, 10, 31, 21, 18, 13
    t2 = t - 1.month
    t2.to_s.should eq("2014-09-30 21:18:13")

    t = Time.new 2014, 10, 31, 21, 18, 13
    t2 = t + 6.month
    t2.to_s.should eq("2015-04-30 21:18:13")
  end

  it "add years" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t2 = t + 1.year
    t2.to_s.should eq("2015-10-30 21:18:13")

    t = Time.new 2014, 10, 30, 21, 18, 13
    t2 = t - 2.years
    t2.to_s.should eq("2012-10-30 21:18:13")
  end

  it "add hours" do
    t1 = Time.new TimeSpecTicks[1]
    t1 = t1 + 10.hours

    t1.day.should eq(26)
    t1.hour.should eq(1)
    t1.minute.should eq(25)
    t1.second.should eq(13)

    t1 = t1 - 3.7.hours
    t1.day.should eq(25)
    t1.hour.should eq(21)
    t1.minute.should eq(43)
    t1.second.should eq(13)

    t1 = t1 + 3.732.hours
    t1.day.should eq(26)
    t1.hour.should eq(1)
    t1.minute.should eq(27)
    t1.second.should eq(8)
  end

  it "add milliseconds" do
    t1 = Time.new TimeSpecTicks[1]
    t1 = t1 + 1e10.milliseconds

    t1.day.should eq(21)
    t1.hour.should eq(9)
    t1.minute.should eq(11)
    t1.second.should eq(53)

    t1 = t1 - 19e10.milliseconds
    t1.day.should eq(13)
    t1.hour.should eq(7)
    t1.minute.should eq(25)
    t1.second.should eq(13)

    t1 = t1 + 15.623.milliseconds
    t1.day.should eq(13)
    t1.hour.should eq(7)
    t1.minute.should eq(25)
    t1.second.should eq(13)
  end

  it "gets time of day" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.time_of_day.should eq(Time::Span.new(21, 18, 13))
  end

  it "gets day of week" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.day_of_week.should eq(Time::DayOfWeek::Thursday)
  end

  it "gets day of year" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.day_of_year.should eq(303)
  end

  it "compares" do
    t1 = Time.new 2014, 10, 30, 21, 18, 13
    t2 = Time.new 2014, 10, 30, 21, 18, 14

    (t1 <=> t2).should eq(-1)
    (t1 == t2).should be_false
    (t1 < t2).should be_true
  end

  it "gets unix epoch seconds" do
    t1 = Time.new 2014, 10, 30, 21, 18, 13, 0, Time::Kind::Utc
    t1.epoch.should eq(1414703893)
    t1.epoch_f.should be_close(1414703893, 1e-01)
  end

  it "gets unix epoch seconds at GMT" do
    t1 = Time.now
    t1.epoch.should eq(t1.to_utc.epoch)
    t1.epoch_f.should be_close(t1.to_utc.epoch_f, 1e-01)
  end

  it "to_s" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.to_s.should eq("2014-10-30 21:18:13")

    t = Time.new 2014, 1, 30, 21, 18, 13
    t.to_s.should eq("2014-01-30 21:18:13")

    t = Time.new 2014, 10, 1, 21, 18, 13
    t.to_s.should eq("2014-10-01 21:18:13")

    t = Time.new 2014, 10, 30, 1, 18, 13
    t.to_s.should eq("2014-10-30 01:18:13")

    t = Time.new 2014, 10, 30, 21, 1, 13
    t.to_s.should eq("2014-10-30 21:01:13")

    t = Time.new 2014, 10, 30, 21, 18, 1
    t.to_s.should eq("2014-10-30 21:18:01")
  end

  it "formats" do
    t = Time.new 2014, 1, 2, 3, 4, 5, 6
    t2 = Time.new 2014, 1, 2, 15, 4, 5, 6
    t3 = Time.new 2014, 1, 2, 12, 4, 5, 6

    t.to_s("%Y").should eq("2014")
    Time.new(1, 1, 2, 3, 4, 5, 6).to_s("%Y").should eq("0001")

    t.to_s("%C").should eq("20")
    t.to_s("%y").should eq("14")
    t.to_s("%m").should eq("01")
    t.to_s("%_m").should eq(" 1")
    t.to_s("%_%_m2").should eq("%_ 12")
    t.to_s("%-m").should eq("1")
    t.to_s("%-%-m2").should eq("%-12")
    t.to_s("%B").should eq("January")
    t.to_s("%^B").should eq("JANUARY")
    t.to_s("%^%^B2").should eq("%^JANUARY2")
    t.to_s("%b").should eq("Jan")
    t.to_s("%^b").should eq("JAN")
    t.to_s("%h").should eq("Jan")
    t.to_s("%^h").should eq("JAN")
    t.to_s("%d").should eq("02")
    t.to_s("%-d").should eq("2")
    t.to_s("%e").should eq(" 2")
    t.to_s("%j").should eq("002")
    t.to_s("%H").should eq("03")

    t.to_s("%k").should eq(" 3")
    t2.to_s("%k").should eq("15")

    t.to_s("%I").should eq("03")
    t2.to_s("%I").should eq("03")
    t3.to_s("%I").should eq("12")

    t.to_s("%l").should eq(" 3")
    t2.to_s("%l").should eq(" 3")
    t3.to_s("%l").should eq("12")

    # Note: we purposely match %p to am/pm and %P to AM/PM (makes more sense)
    t.to_s("%p").should eq("am")
    t2.to_s("%p").should eq("pm")

    t.to_s("%P").should eq("AM")
    t2.to_s("%P").should eq("PM")

    t.to_s("%M").to_s.should eq("04")
    t.to_s("%S").to_s.should eq("05")
    t.to_s("%L").to_s.should eq("006")

    Time.utc_now.to_s("%z").should eq("+0000")
    Time.utc_now.to_s("%:z").should eq("+00:00")
    Time.utc_now.to_s("%::z").should eq("+00:00:00")

    # TODO %N
    # TODO %Z

    t.to_s("%A").to_s.should eq("Thursday")
    t.to_s("%^A").to_s.should eq("THURSDAY")
    t.to_s("%a").to_s.should eq("Thu")
    t.to_s("%^a").to_s.should eq("THU")
    t.to_s("%u").to_s.should eq("4")
    t.to_s("%w").to_s.should eq("4")

    t3 = Time.new 2014, 1, 5 # A Sunday
    t3.to_s("%u").to_s.should eq("7")
    t3.to_s("%w").to_s.should eq("0")

    # TODO %G
    # TODO %g
    # TODO %V
    # TODO %U
    # TODO %W
    # TODO %s
    # TODO %n
    # TODO %t
    # TODO %%

    t.to_s("%%").should eq("%")
    t.to_s("%c").should eq(t.to_s("%a %b %e %T %Y"))
    t.to_s("%D").should eq(t.to_s("%m/%d/%y"))
    t.to_s("%F").should eq(t.to_s("%Y-%m-%d"))
    # TODO %v
    t.to_s("%x").should eq(t.to_s("%D"))
    t.to_s("%X").should eq(t.to_s("%T"))
    t.to_s("%r").should eq(t.to_s("%I:%M:%S %P"))
    t.to_s("%R").should eq(t.to_s("%H:%M"))
    t.to_s("%T").should eq(t.to_s("%H:%M:%S"))

    t.to_s("%Y-%m-hello").should eq("2014-01-hello")

    t = Time.new 2014, 1, 2, 3, 4, 5, 6, kind: Time::Kind::Utc
    t.to_s("%s").should eq("1388631845")
  end

  it "parses empty" do
    t = Time.parse("", "")
    t.year.should eq(1)
    t.month.should eq(1)
    t.day.should eq(1)
    t.hour.should eq(0)
    t.minute.should eq(0)
    t.second.should eq(0)
    t.millisecond.should eq(0)
  end

  it { Time.parse("2014", "%Y").year.should eq(2014) }
  it { Time.parse("19", "%C").year.should eq(1900) }
  it { Time.parse("14", "%y").year.should eq(2014) }
  it { Time.parse("09", "%m").month.should eq(9) }
  it { Time.parse(" 9", "%_m").month.should eq(9) }
  it { Time.parse("9", "%-m").month.should eq(9) }
  it { Time.parse("February", "%B").month.should eq(2) }
  it { Time.parse("March", "%B").month.should eq(3) }
  it { Time.parse("MaRcH", "%B").month.should eq(3) }
  it { Time.parse("MaR", "%B").month.should eq(3) }
  it { Time.parse("MARCH", "%^B").month.should eq(3) }
  it { Time.parse("Mar", "%b").month.should eq(3) }
  it { Time.parse("Mar", "%^b").month.should eq(3) }
  it { Time.parse("MAR", "%^b").month.should eq(3) }
  it { Time.parse("MAR", "%h").month.should eq(3) }
  it { Time.parse("MAR", "%^h").month.should eq(3) }
  it { Time.parse("2", "%d").day.should eq(2) }
  it { Time.parse("02", "%d").day.should eq(2) }
  it { Time.parse("02", "%-d").day.should eq(2) }
  it { Time.parse(" 2", "%e").day.should eq(2) }
  it { Time.parse("9", "%H").hour.should eq(9) }
  it { Time.parse(" 9", "%k").hour.should eq(9) }
  it { Time.parse("09", "%I").hour.should eq(9) }
  it { Time.parse(" 9", "%l").hour.should eq(9) }
  it { Time.parse("9pm", "%l%p").hour.should eq(21) }
  it { Time.parse("9PM", "%l%P").hour.should eq(21) }
  it { Time.parse("09", "%M").minute.should eq(9) }
  it { Time.parse("09", "%S").second.should eq(9) }
  it { Time.parse("123", "%L").millisecond.should eq(123) }
  it { Time.parse("Fri Oct 31 23:00:24 2014", "%c").to_s.should eq("2014-10-31 23:00:24") }
  it { Time.parse("10/31/14", "%D").to_s.should eq("2014-10-31 00:00:00") }
  it { Time.parse("10/31/69", "%D").to_s.should eq("1969-10-31 00:00:00") }
  it { Time.parse("2014-10-31", "%F").to_s.should eq("2014-10-31 00:00:00") }
  it { Time.parse("2014-10-31", "%F").to_s.should eq("2014-10-31 00:00:00") }
  it { Time.parse("10/31/14", "%x").to_s.should eq("2014-10-31 00:00:00") }
  it { Time.parse("10:11:12", "%X").to_s.should eq("0001-01-01 10:11:12") }
  it { Time.parse("11:14:01 PM", "%r").to_s.should eq("0001-01-01 23:14:01") }
  it { Time.parse("11:14", "%R").to_s.should eq("0001-01-01 11:14:00") }
  it { Time.parse("11:12:13", "%T").to_s.should eq("0001-01-01 11:12:13") }
  it { Time.parse("This was done on Friday, October 31, 2014", "This was done on %A, %B %d, %Y").to_s.should eq("2014-10-31 00:00:00") }
  it { Time.parse("今は Friday, October 31, 2014", "今は %A, %B %d, %Y").to_s.should eq("2014-10-31 00:00:00") }
  it { Time.parse("epoch: 1459864667", "epoch: %s").epoch.should eq(1459864667) }
  it { Time.parse("epoch: -1459864667", "epoch: %s").epoch.should eq(-1459864667) }

  # TODO %N
  # TODO %Z
  # TODO %G
  # TODO %g
  # TODO %V
  # TODO %U
  # TODO %W
  # TODO %s
  # TODO %n
  # TODO %t
  # TODO %%
  # TODO %v

  it do
    time = Time.parse("2014-10-31 10:11:12 Z hi", "%F %T %z hi")
    time.utc?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 10:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 UTC hi", "%F %T %z hi")
    time.utc?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 10:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 -06:00 hi", "%F %T %z hi")
    time.local?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 +05:00 hi", "%F %T %z hi")
    time.local?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 05:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 -06:00:00 hi", "%F %T %z hi")
    time.local?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 -060000 hi", "%F %T %z hi")
    time.local?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it "parses microseconds" do
    time = Time.parse("2016-09-09T17:03:28.456789+01:00", "%FT%T.%L%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(456)
  end

  it "parses the correct amount of digits (#853)" do
    time = Time.parse("20150624", "%Y%m%d")
    time.year.should eq(2015)
    time.month.should eq(6)
    time.day.should eq(24)
  end

  it "parses month blank padded" do
    time = Time.parse("2015 624", "%Y%_m%d")
    time.year.should eq(2015)
    time.month.should eq(6)
    time.day.should eq(24)
  end

  it "parses day of month blank padded" do
    time = Time.parse("201506 4", "%Y%m%e")
    time.year.should eq(2015)
    time.month.should eq(6)
    time.day.should eq(4)
  end

  it "parses hour 24 blank padded" do
    time = Time.parse(" 31112", "%k%M%S")
    time.hour.should eq(3)
    time.minute.should eq(11)
    time.second.should eq(12)
  end

  it "parses hour 12 blank padded" do
    time = Time.parse(" 31112", "%l%M%S")
    time.hour.should eq(3)
    time.minute.should eq(11)
    time.second.should eq(12)
  end

  it "can parse in UTC" do
    time = Time.parse("2014-10-31 11:12:13", "%F %T", Time::Kind::Utc)
    time.kind.should eq(Time::Kind::Utc)
  end

  it "at" do
    t1 = Time.new 2014, 11, 25, 10, 11, 12, 13
    t2 = Time.new 2014, 6, 25, 10, 11, 12, 13

    t1.at_beginning_of_year.to_s.should eq("2014-01-01 00:00:00")

    1.upto(3) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s.should eq("2014-01-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s.should eq("2014-03-31 23:59:59")
    end
    4.upto(6) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s.should eq("2014-04-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s.should eq("2014-06-30 23:59:59")
    end
    7.upto(9) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s.should eq("2014-07-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s.should eq("2014-09-30 23:59:59")
    end
    10.upto(12) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s.should eq("2014-10-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s.should eq("2014-12-31 23:59:59")
    end

    t1.at_beginning_of_quarter.to_s.should eq("2014-10-01 00:00:00")
    t1.at_beginning_of_month.to_s.should eq("2014-11-01 00:00:00")

    3.upto(9) do |i|
      Time.new(2014, 11, i).at_beginning_of_week.to_s.should eq("2014-11-03 00:00:00")
    end

    t1.at_beginning_of_day.to_s.should eq("2014-11-25 00:00:00")
    t1.at_beginning_of_hour.to_s.should eq("2014-11-25 10:00:00")
    t1.at_beginning_of_minute.to_s.should eq("2014-11-25 10:11:00")

    t1.at_end_of_year.to_s.should eq("2014-12-31 23:59:59")

    t1.at_end_of_quarter.to_s.should eq("2014-12-31 23:59:59")
    t2.at_end_of_quarter.to_s.should eq("2014-06-30 23:59:59")

    t1.at_end_of_month.to_s.should eq("2014-11-30 23:59:59")
    t1.at_end_of_week.to_s.should eq("2014-11-30 23:59:59")

    Time.new(2014, 11, 2).at_end_of_week.to_s.should eq("2014-11-02 23:59:59")
    3.upto(9) do |i|
      Time.new(2014, 11, i).at_end_of_week.to_s.should eq("2014-11-09 23:59:59")
    end

    t1.at_end_of_day.to_s.should eq("2014-11-25 23:59:59")
    t1.at_end_of_hour.to_s.should eq("2014-11-25 10:59:59")
    t1.at_end_of_minute.to_s.should eq("2014-11-25 10:11:59")

    t1.at_midday.to_s.should eq("2014-11-25 12:00:00")

    t1.at_beginning_of_semester.to_s.should eq("2014-07-01 00:00:00")
    t2.at_beginning_of_semester.to_s.should eq("2014-01-01 00:00:00")

    t1.at_end_of_semester.to_s.should eq("2014-12-31 23:59:59")
    t2.at_end_of_semester.to_s.should eq("2014-06-30 23:59:59")
  end

  it "does time span units" do
    1.millisecond.ticks.should eq(Time::Span::TicksPerMillisecond)
    1.milliseconds.ticks.should eq(Time::Span::TicksPerMillisecond)
    1.second.ticks.should eq(Time::Span::TicksPerSecond)
    1.seconds.ticks.should eq(Time::Span::TicksPerSecond)
    1.minute.ticks.should eq(Time::Span::TicksPerMinute)
    1.minutes.ticks.should eq(Time::Span::TicksPerMinute)
    1.hour.ticks.should eq(Time::Span::TicksPerHour)
    1.hours.ticks.should eq(Time::Span::TicksPerHour)
    1.week.should eq(7.days)
    2.weeks.should eq(14.days)
  end

  it "preserves kind when adding" do
    time = Time.utc_now
    time.kind.should eq(Time::Kind::Utc)

    (time + 5.minutes).kind.should eq(Time::Kind::Utc)
  end

  it "asks for day name" do
    7.times do |i|
      time = Time.new(2015, 2, 15 + i)
      time.sunday?.should eq(i == 0)
      time.monday?.should eq(i == 1)
      time.tuesday?.should eq(i == 2)
      time.wednesday?.should eq(i == 3)
      time.thursday?.should eq(i == 4)
      time.friday?.should eq(i == 5)
      time.saturday?.should eq(i == 6)
    end
  end

  it "compares different kinds" do
    time = Time.now
    (time.to_utc <=> time).should eq(0)
  end

  it %(changes timezone with ENV["TZ"]) do
    old_tz = ENV["TZ"]?

    begin
      ENV["TZ"] = "America/New_York"
      offset1 = Time.local_offset_in_minutes

      ENV["TZ"] = "Europe/Berlin"
      offset2 = Time.local_offset_in_minutes

      offset1.should_not eq(offset2)
    ensure
      ENV["TZ"] = old_tz
    end
  end

  it "does diff of utc vs local time" do
    local = Time.now
    utc = local.to_utc
    (utc - local).should eq(0.seconds)
    (local - utc).should eq(0.seconds)
  end

  typeof(Time.now.year)
  typeof(1.minute.from_now.year)
  typeof(1.minute.ago.year)
  typeof(1.month.from_now.year)
  typeof(1.month.ago.year)
  typeof(Time.now.to_utc)
  typeof(Time.now.to_local)
end

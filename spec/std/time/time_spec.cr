require "spec"

TimeSpecTicks = [
  631501920000000000_i64, # 25 Feb 2002 - 00:00:00
  631502475130080000_i64, # 25 Feb 2002 - 15:25:13,8
  631502115130080000_i64, # 25 Feb 2002 - 05:25:13,8
]

def Time.expect_invalid
  expect_raises ArgumentError, "invalid time" do
    yield
  end
end

describe Time do
  it "initialize" do
    t1 = Time.new 2002, 2, 25
    expect(t1.ticks).to eq(TimeSpecTicks[0])

    t2 = Time.new 2002, 2, 25, 15, 25, 13, 8
    expect(t2.ticks).to eq(TimeSpecTicks[1])

    expect(t2.date.ticks).to eq(TimeSpecTicks[0])
    expect(t2.year).to eq(2002)
    expect(t2.month).to eq(2)
    expect(t2.day).to eq(25)
    expect(t2.hour).to eq(15)
    expect(t2.minute).to eq(25)
    expect(t2.second).to eq(13)
    expect(t2.millisecond).to eq(8)

    t3 = Time.new 2002, 2, 25, 5, 25, 13, 8
    expect(t3.ticks).to eq(TimeSpecTicks[2])
  end

  it "initialize max" do
    expect(Time.new(9999, 12, 31, 23, 59, 59, 999).ticks).to eq(3155378975999990000)
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

  it "fields" do
    expect(Time::MaxValue.ticks).to eq(3155378975999999999)
    expect(Time::MinValue.ticks).to eq(0)
  end

  it "add" do
    t1 = Time.new TimeSpecTicks[1]
    span = TimeSpan.new 3, 54, 1
    t2 = t1 + span

    expect(t2.day).to eq(25)
    expect(t2.hour).to eq(19)
    expect(t2.minute).to eq(19)
    expect(t2.second).to eq(14)

    expect(t1.day).to eq(25)
    expect(t1.hour).to eq(15)
    expect(t1.minute).to eq(25)
    expect(t1.second).to eq(13)
  end

  it "add out of range 1" do
    t1 = Time.new TimeSpecTicks[1]

    expect_raises ArgumentError do
      t1 + TimeSpan::MaxValue
    end
  end

  it "add out of range 2" do
    t1 = Time.new TimeSpecTicks[1]

    expect_raises ArgumentError do
      t1 + TimeSpan::MinValue
    end
  end

  it "add days" do
    t1 = Time.new TimeSpecTicks[1]
    t1 = t1 + 3.days

    expect(t1.day).to eq(28)
    expect(t1.hour).to eq(15)
    expect(t1.minute).to eq(25)
    expect(t1.second).to eq(13)

    t1 = t1 + 1.9.days
    expect(t1.day).to eq(2)
    expect(t1.hour).to eq(13)
    expect(t1.minute).to eq(1)
    expect(t1.second).to eq(13)

    t1 = t1 + 0.2.days
    expect(t1.day).to eq(2)
    expect(t1.hour).to eq(17)
    expect(t1.minute).to eq(49)
    expect(t1.second).to eq(13)
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
    expect(t2.to_s).to eq("2014-11-30 21:18:13")

    t2 = t + 1.months
    expect(t2.to_s).to eq("2014-11-30 21:18:13")

    t = Time.new 2014, 10, 31, 21, 18, 13
    t2 = t + 1.month
    expect(t2.to_s).to eq("2014-11-30 21:18:13")

    t = Time.new 2014, 10, 31, 21, 18, 13
    t2 = t - 1.month
    expect(t2.to_s).to eq("2014-09-30 21:18:13")
  end

  it "add years" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t2 = t + 1.year
    expect(t2.to_s).to eq("2015-10-30 21:18:13")

    t = Time.new 2014, 10, 30, 21, 18, 13
    t2 = t - 2.years
    expect(t2.to_s).to eq("2012-10-30 21:18:13")
  end

  it "add hours" do
    t1 = Time.new TimeSpecTicks[1]
    t1 = t1 + 10.hours

    expect(t1.day).to eq(26)
    expect(t1.hour).to eq(1)
    expect(t1.minute).to eq(25)
    expect(t1.second).to eq(13)

    t1 = t1 - 3.7.hours
    expect(t1.day).to eq(25)
    expect(t1.hour).to eq(21)
    expect(t1.minute).to eq(43)
    expect(t1.second).to eq(13)

    t1 = t1 + 3.732.hours
    expect(t1.day).to eq(26)
    expect(t1.hour).to eq(1)
    expect(t1.minute).to eq(27)
    expect(t1.second).to eq(8)
  end

  it "add milliseconds" do
    t1 = Time.new TimeSpecTicks[1]
    t1 = t1 + 1e10.milliseconds

    expect(t1.day).to eq(21)
    expect(t1.hour).to eq(9)
    expect(t1.minute).to eq(11)
    expect(t1.second).to eq(53)

    t1 = t1 - 19e10.milliseconds
    expect(t1.day).to eq(13)
    expect(t1.hour).to eq(7)
    expect(t1.minute).to eq(25)
    expect(t1.second).to eq(13)

    t1 = t1 + 15.623.milliseconds
    expect(t1.day).to eq(13)
    expect(t1.hour).to eq(7)
    expect(t1.minute).to eq(25)
    expect(t1.second).to eq(13)
  end

  it "gets time of day" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    expect(t.time_of_day).to eq(TimeSpan.new(21, 18, 13))
  end

  it "gets day of week" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    expect(t.day_of_week).to eq(DayOfWeek::Thursday)
  end

  it "gets day of year" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    expect(t.day_of_year).to eq(303)
  end

  it "compares" do
    t1 = Time.new 2014, 10, 30, 21, 18, 13
    t2 = Time.new 2014, 10, 30, 21, 18, 14

    expect((t1 <=> t2)).to eq(-1)
    expect((t1 == t2)).to be_false
    expect((t1 < t2)).to be_true
  end

  it "gets unix epoch seconds" do
    t1 = Time.new 2014, 10, 30, 21, 18, 13
    expect(t1.to_i).to eq(1414703893)
    expect(t1.to_f).to be_close(1414703893, 1e-01)
  end

  it "to_s" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    expect(t.to_s).to eq("2014-10-30 21:18:13")

    t = Time.new 2014, 1, 30, 21, 18, 13
    expect(t.to_s).to eq("2014-01-30 21:18:13")

    t = Time.new 2014, 10, 1, 21, 18, 13
    expect(t.to_s).to eq("2014-10-01 21:18:13")

    t = Time.new 2014, 10, 30, 1, 18, 13
    expect(t.to_s).to eq("2014-10-30 01:18:13")

    t = Time.new 2014, 10, 30, 21, 1, 13
    expect(t.to_s).to eq("2014-10-30 21:01:13")

    t = Time.new 2014, 10, 30, 21, 18, 1
    expect(t.to_s).to eq("2014-10-30 21:18:01")
  end

  it "formats" do
    t = Time.new 2014, 1, 2, 3, 4, 5, 6
    t2 = Time.new 2014, 1, 2, 15, 4, 5, 6

    expect(t.to_s("%Y")).to eq("2014")
    expect(Time.new(1, 1, 2, 3, 4, 5, 6).to_s("%Y")).to eq("0001")

    expect(t.to_s("%C")).to eq("20")
    expect(t.to_s("%y")).to eq("14")
    expect(t.to_s("%m")).to eq("01")
    expect(t.to_s("%_m")).to eq(" 1")
    expect(t.to_s("%-m")).to eq("1")
    expect(t.to_s("%B")).to eq("January")
    expect(t.to_s("%^B")).to eq("JANUARY")
    expect(t.to_s("%b")).to eq("Jan")
    expect(t.to_s("%^b")).to eq("JAN")
    expect(t.to_s("%h")).to eq("Jan")
    expect(t.to_s("%^h")).to eq("JAN")
    expect(t.to_s("%d")).to eq("02")
    expect(t.to_s("%-d")).to eq("2")
    expect(t.to_s("%e")).to eq(" 2")
    expect(t.to_s("%j")).to eq("002")
    expect(t.to_s("%H")).to eq("03")

    expect(t.to_s("%k")).to eq(" 3")
    expect(t2.to_s("%k")).to eq("15")

    expect(t.to_s("%I")).to eq("03")
    expect(t2.to_s("%I")).to eq("03")

    expect(t.to_s("%l")).to eq(" 3")
    expect(t2.to_s("%l")).to eq(" 3")

    # Note: we purposely match %p to am/pm and %P to AM/PM (makes more sense)
    expect(t.to_s("%p")).to eq("am")
    expect(t2.to_s("%p")).to eq("pm")

    expect(t.to_s("%P")).to eq("AM")
    expect(t2.to_s("%P")).to eq("PM")

    expect(t.to_s("%M").to_s).to eq("04")
    expect(t.to_s("%S").to_s).to eq("05")
    expect(t.to_s("%L").to_s).to eq("006")

    # TODO %N
    # TODO %z
    # TODO %Z

    expect(t.to_s("%A").to_s).to eq("Thursday")
    expect(t.to_s("%^A").to_s).to eq("THURSDAY")
    expect(t.to_s("%a").to_s).to eq("Thu")
    expect(t.to_s("%^a").to_s).to eq("THU")
    expect(t.to_s("%u").to_s).to eq("4")
    expect(t.to_s("%w").to_s).to eq("4")

    t3 = Time.new 2014, 1, 5 # A Sunday
    expect(t3.to_s("%u").to_s).to eq("7")
    expect(t3.to_s("%w").to_s).to eq("0")

    # TODO %G
    # TODO %g
    # TODO %V
    # TODO %U
    # TODO %W
    # TODO %s
    # TODO %n
    # TODO %t
    # TODO %%

    expect(t.to_s("%%")).to eq("%")
    expect(t.to_s("%c")).to eq(t.to_s("%a %b %e %T %Y"))
    expect(t.to_s("%D")).to eq(t.to_s("%m/%d/%y"))
    expect(t.to_s("%F")).to eq(t.to_s("%Y-%m-%d"))
    # TODO %v
    expect(t.to_s("%x")).to eq(t.to_s("%D"))
    expect(t.to_s("%X")).to eq(t.to_s("%T"))
    expect(t.to_s("%r")).to eq(t.to_s("%I:%M:%S %P"))
    expect(t.to_s("%R")).to eq(t.to_s("%H:%M"))
    expect(t.to_s("%T")).to eq(t.to_s("%H:%M:%S"))

    expect(t.to_s("%Y-%m-hello")).to eq("2014-01-hello")
  end

  it "parses with format" do
    t = Time.parse("", "")
    expect(t.year).to eq(1)
    expect(t.month).to eq(1)
    expect(t.day).to eq(1)
    expect(t.hour).to eq(0)
    expect(t.minute).to eq(0)
    expect(t.second).to eq(0)
    expect(t.millisecond).to eq(0)

    expect(Time.parse("2014", "%Y").year).to eq(2014)
    expect(Time.parse("19", "%C").year).to eq(1900)
    expect(Time.parse("14", "%y").year).to eq(2014)
    expect(Time.parse("09", "%m").month).to eq(9)
    expect(Time.parse(" 9", "%_m").month).to eq(9)
    expect(Time.parse("9", "%-m").month).to eq(9)
    expect(Time.parse("February", "%B").month).to eq(2)
    expect(Time.parse("March", "%B").month).to eq(3)
    expect(Time.parse("MaRcH", "%B").month).to eq(3)
    expect(Time.parse("MaR", "%B").month).to eq(3)
    expect(Time.parse("MARCH", "%^B").month).to eq(3)
    expect(Time.parse("Mar", "%b").month).to eq(3)
    expect(Time.parse("Mar", "%^b").month).to eq(3)
    expect(Time.parse("MAR", "%^b").month).to eq(3)
    expect(Time.parse("MAR", "%h").month).to eq(3)
    expect(Time.parse("MAR", "%^h").month).to eq(3)
    expect(Time.parse("2", "%d").day).to eq(2)
    expect(Time.parse("02", "%d").day).to eq(2)
    expect(Time.parse("02", "%-d").day).to eq(2)
    expect(Time.parse(" 2", "%e").day).to eq(2)
    expect(Time.parse("0123", "%j").year).to eq(123)
    expect(Time.parse("9", "%H").hour).to eq(9)
    expect(Time.parse(" 9", "%k").hour).to eq(9)
    expect(Time.parse("09", "%I").hour).to eq(9)
    expect(Time.parse(" 9", "%l").hour).to eq(9)
    expect(Time.parse("9pm", "%l%p").hour).to eq(21)
    expect(Time.parse("9PM", "%l%P").hour).to eq(21)
    expect(Time.parse("09", "%M").minute).to eq(9)
    expect(Time.parse("09", "%S").second).to eq(9)
    expect(Time.parse("123", "%L").millisecond).to eq(123)

    # TODO %N
    # TODO %z
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

    expect(Time.parse("Fri Oct 31 23:00:24 2014", "%c").to_s).to eq("2014-10-31 23:00:24")
    expect(Time.parse("10/31/14", "%D").to_s).to eq("2014-10-31 00:00:00")
    expect(Time.parse("10/31/69", "%D").to_s).to eq("1969-10-31 00:00:00")
    expect(Time.parse("2014-10-31", "%F").to_s).to eq("2014-10-31 00:00:00")
    expect(Time.parse("2014-10-31", "%F").to_s).to eq("2014-10-31 00:00:00")
    # TODO %v
    expect(Time.parse("10/31/14", "%x").to_s).to eq("2014-10-31 00:00:00")
    expect(Time.parse("10:11:12", "%X").to_s).to eq("0001-01-01 10:11:12")
    expect(Time.parse("11:14:01 PM", "%r").to_s).to eq("0001-01-01 23:14:01")
    expect(Time.parse("11:14", "%R").to_s).to eq("0001-01-01 11:14:00")
    expect(Time.parse("11:12:13", "%T").to_s).to eq("0001-01-01 11:12:13")

    expect(Time.parse("This was done on Friday, October 31, 2014", "This was done on %A, %B %d, %Y").to_s).to eq("2014-10-31 00:00:00")
    expect(Time.parse("今は Friday, October 31, 2014", "今は %A, %B %d, %Y").to_s).to eq("2014-10-31 00:00:00")
  end

  it "at" do
    t1 = Time.new 2014, 11, 25, 10, 11, 12, 13
    t2 = Time.new 2014, 6, 25, 10, 11, 12, 13

    expect(t1.at_beginning_of_year.to_s).to eq("2014-01-01 00:00:00")

    1.upto(3) do |i|
      expect(Time.new(2014, i, 10).at_beginning_of_quarter.to_s).to eq("2014-01-01 00:00:00")
      expect(Time.new(2014, i, 10).at_end_of_quarter.to_s).to eq("2014-03-31 23:59:59")
    end
    4.upto(6) do |i|
      expect(Time.new(2014, i, 10).at_beginning_of_quarter.to_s).to eq("2014-04-01 00:00:00")
      expect(Time.new(2014, i, 10).at_end_of_quarter.to_s).to eq("2014-06-30 23:59:59")
    end
    7.upto(9) do |i|
      expect(Time.new(2014, i, 10).at_beginning_of_quarter.to_s).to eq("2014-07-01 00:00:00")
      expect(Time.new(2014, i, 10).at_end_of_quarter.to_s).to eq("2014-09-30 23:59:59")
    end
    10.upto(12) do |i|
      expect(Time.new(2014, i, 10).at_beginning_of_quarter.to_s).to eq("2014-10-01 00:00:00")
      expect(Time.new(2014, i, 10).at_end_of_quarter.to_s).to eq("2014-12-31 23:59:59")
    end

    expect(t1.at_beginning_of_quarter.to_s).to eq("2014-10-01 00:00:00")
    expect(t1.at_beginning_of_month.to_s).to eq("2014-11-01 00:00:00")

    3.upto(9) do |i|
      expect(Time.new(2014, 11, i).at_beginning_of_week.to_s).to eq("2014-11-03 00:00:00")
    end

    expect(t1.at_beginning_of_day.to_s).to eq("2014-11-25 00:00:00")
    expect(t1.at_beginning_of_hour.to_s).to eq("2014-11-25 10:00:00")
    expect(t1.at_beginning_of_minute.to_s).to eq("2014-11-25 10:11:00")

    expect(t1.at_end_of_year.to_s).to eq("2014-12-31 23:59:59")

    expect(t1.at_end_of_quarter.to_s).to eq("2014-12-31 23:59:59")
    expect(t2.at_end_of_quarter.to_s).to eq("2014-06-30 23:59:59")

    expect(t1.at_end_of_month.to_s).to eq("2014-11-30 23:59:59")
    expect(t1.at_end_of_week.to_s).to eq("2014-11-30 23:59:59")

    expect(Time.new(2014, 11, 2).at_end_of_week.to_s).to eq("2014-11-02 23:59:59")
    3.upto(9) do |i|
      expect(Time.new(2014, 11, i).at_end_of_week.to_s).to eq("2014-11-09 23:59:59")
    end

    expect(t1.at_end_of_day.to_s).to eq("2014-11-25 23:59:59")
    expect(t1.at_end_of_hour.to_s).to eq("2014-11-25 10:59:59")
    expect(t1.at_end_of_minute.to_s).to eq("2014-11-25 10:11:59")

    expect(t1.at_midday.to_s).to eq("2014-11-25 12:00:00")

    expect(t1.at_beginning_of_semester.to_s).to eq("2014-07-01 00:00:00")
    expect(t2.at_beginning_of_semester.to_s).to eq("2014-01-01 00:00:00")

    expect(t1.at_end_of_semester.to_s).to eq("2014-12-31 23:59:59")
    expect(t2.at_end_of_semester.to_s).to eq("2014-06-30 23:59:59")
  end

  it "does time span units" do
    expect(1.millisecond.ticks).to eq(TimeSpan::TicksPerMillisecond)
    expect(1.milliseconds.ticks).to eq(TimeSpan::TicksPerMillisecond)
    expect(1.second.ticks).to eq(TimeSpan::TicksPerSecond)
    expect(1.seconds.ticks).to eq(TimeSpan::TicksPerSecond)
    expect(1.minute.ticks).to eq(TimeSpan::TicksPerMinute)
    expect(1.minutes.ticks).to eq(TimeSpan::TicksPerMinute)
    expect(1.hour.ticks).to eq(TimeSpan::TicksPerHour)
    expect(1.hours.ticks).to eq(TimeSpan::TicksPerHour)
  end

  it "preserves kind when adding" do
    time = Time.utc_now
    expect(time.kind).to eq(Time::Kind::Utc)

    expect((time + 5.minutes).kind).to eq(Time::Kind::Utc)
  end

  it "asks for day name" do
    7.times do |i|
      time = Time.new(2015, 2, 15 + i)
      expect(time.sunday?).to eq(i == 0)
      expect(time.monday?).to eq(i == 1)
      expect(time.tuesday?).to eq(i == 2)
      expect(time.wednesday?).to eq(i == 3)
      expect(time.thursday?).to eq(i == 4)
      expect(time.friday?).to eq(i == 5)
      expect(time.saturday?).to eq(i == 6)
    end
  end

  typeof(Time.now.year)
  typeof(1.minute.from_now.year)
  typeof(1.minute.ago.year)
  typeof(1.month.from_now.year)
  typeof(1.month.ago.year)
end

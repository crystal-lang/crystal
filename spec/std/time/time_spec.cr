require "spec"
require "./spec_helper"

def Time.expect_invalid
  expect_raises ArgumentError, "Invalid time" do
    yield
  end
end

private def parse_time(format, string)
  Time.parse(format, string, Time::Location::UTC)
end

describe Time do
  it "initialize" do
    t1 = Time.new 2002, 2, 25
    t1.year.should eq(2002)
    t1.month.should eq(2)
    t1.day.should eq(25)
    t1.local?.should be_true

    t2 = Time.new 2002, 2, 25, 15, 25, 13, nanosecond: 8
    t2.year.should eq(2002)
    t2.month.should eq(2)
    t2.day.should eq(25)
    t2.hour.should eq(15)
    t2.minute.should eq(25)
    t2.second.should eq(13)
    t2.nanosecond.should eq(8)
    t2.local?.should be_true
  end

  it "initialize max" do
    time = Time.new(9999, 12, 31, 23, 59, 59, nanosecond: 999_999_999)
    time.year.should eq(9999)
    time.month.should eq(12)
    time.day.should eq(31)
    time.hour.should eq(23)
    time.minute.should eq(59)
    time.second.should eq(59)
    time.nanosecond.should eq(999_999_999)
  end

  it "fail initialize with negative nanosecond" do
    Time.expect_invalid do
      Time.new(9999, 12, 31, 23, 59, 59, nanosecond: -1)
    end
  end

  it "fail initialize with 1_000_000_000 nanoseconds" do
    Time.expect_invalid do
      Time.new(9999, 12, 31, 23, 59, 59, nanosecond: 1_000_000_000)
    end
  end

  it "#initialize checks boundary at time min" do
    {-5 * 3600, -1, 0, 1, 5 * 3600}.each do |offset|
      seconds = -offset.to_i64
      Time.new(seconds: seconds + 1, nanoseconds: 0, location: Time::Location.fixed(offset))
      Time.new(seconds: seconds, nanoseconds: 0, location: Time::Location.fixed(offset))
      Time.expect_invalid do
        Time.new(seconds: seconds - 1, nanoseconds: 0, location: Time::Location.fixed(offset))
      end
    end
  end

  it "#initialize checks boundary at time max" do
    {-5 * 3600, -1, 0, 1, 5 * 3600}.each do |offset|
      seconds = Time::MAX_SECONDS - offset.to_i64
      Time.new(seconds: seconds - 1, nanoseconds: 0, location: Time::Location.fixed(offset))
      Time.new(seconds: seconds, nanoseconds: 0, location: Time::Location.fixed(offset))
      Time.expect_invalid do
        Time.new(seconds: seconds + 1, nanoseconds: 0, location: Time::Location.fixed(offset))
      end
    end
  end

  it "initialize with .epoch" do
    seconds = 1439404155
    time = Time.epoch(seconds)
    time.should eq(Time.utc(2015, 8, 12, 18, 29, 15))
    time.epoch.should eq(seconds)
    time.utc?.should be_true
  end

  it "initialize with .epoch_ms" do
    milliseconds = 1439404155000
    time = Time.epoch_ms(milliseconds)
    time.should eq(Time.utc(2015, 8, 12, 18, 29, 15))
    time.epoch_ms.should eq(milliseconds)
    time.utc?.should be_true
  end

  it "returns always increasing monotonic clock" do
    clock = Time.monotonic
    Time.monotonic.should be >= clock
  end

  it "measures elapsed time" do
    # NOTE: On some systems, the sleep may not always wait for 1ms and the fiber
    #       be resumed early. We thus merely test that the method returns a
    #       positive time span.
    elapsed = Time.measure { sleep 1.millisecond }
    elapsed.should be >= 0.seconds
  end

  it "clones" do
    time = Time.now
    (time == time.clone).should be_true
  end

  it "add" do
    t1 = Time.utc(2002, 2, 25, 15, 25, 13)
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

    t2.location.should eq t1.location
  end

  it "add out of range 1" do
    t1 = Time.utc(9980, 2, 25, 15, 25, 13)

    expect_raises ArgumentError do
      t1 + Time::Span.new(nanoseconds: Int64::MAX)
    end
  end

  it "add out of range 2" do
    t1 = Time.utc(1, 2, 25, 15, 25, 13)

    expect_raises ArgumentError do
      t1 + Time::Span.new(nanoseconds: Int64::MIN)
    end
  end

  it "#add_span checks boundary at time min" do
    {5 * 3600, 1, 0, -1, -5 * 3600}.each do |offset|
      location = Time::Location.fixed(offset)

      time = Time.new(1, 1, 1, location: location)
      time.add_span(0, 1).should eq Time.new(1, 1, 1, nanosecond: 1, location: location)
      time.add_span(0, 0).should eq time
      expect_raises(ArgumentError) do
        time.add_span(0, -1)
      end
    end
  end

  it "#add_span checks boundary at time max" do
    {5 * 3600, 1, 0, -1, -5 * 3600}.each do |offset|
      location = Time::Location.fixed(offset)

      time = Time.new(9999, 12, 31, 23, 59, 59, nanosecond: 999_999_999, location: location)
      time.add_span(0, -1).should eq Time.new(9999, 12, 31, 23, 59, 59, nanosecond: 999_999_998, location: location)
      time.add_span(0, 0).should eq time
      expect_raises(ArgumentError) do
        time.add_span(0, 1)
      end
    end
  end

  it "adds zero span" do
    time = Time.now
    time.add_span(0, 0).should eq time
  end

  it "add days" do
    t1 = Time.utc(2002, 2, 25, 15, 25, 13)
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

  pending "add days over dst" do
    with_zoneinfo do
      location = Time::Location.load("Europe/Berlin")
      reference = Time.new(2017, 10, 28, 13, 37, location: location)
      next_day = Time.new(2017, 10, 29, 13, 37, location: location)

      (reference + 1.day).should eq next_day
    end
  end

  it "add days out of range 1" do
    t1 = Time.utc(2002, 2, 25, 15, 25, 13)
    expect_raises ArgumentError do
      t1 + 10000000.days
    end
  end

  it "add days out of range 2" do
    t1 = Time.utc(2002, 2, 25, 15, 25, 13)
    expect_raises ArgumentError do
      t1 - 10000000.days
    end
  end

  it "add months" do
    t = Time.utc 2014, 10, 30, 21, 18, 13
    t2 = t + 1.month
    t2.to_s.should eq("2014-11-30 21:18:13 UTC")

    t2 = t + 1.months
    t2.to_s.should eq("2014-11-30 21:18:13 UTC")

    t = Time.utc 2014, 10, 31, 21, 18, 13
    t2 = t + 1.month
    t2.to_s.should eq("2014-11-30 21:18:13 UTC")

    t = Time.utc 2014, 10, 31, 21, 18, 13
    t2 = t - 1.month
    t2.to_s.should eq("2014-09-30 21:18:13 UTC")

    t = Time.utc 2014, 10, 31, 21, 18, 13
    t2 = t + 6.month
    t2.to_s.should eq("2015-04-30 21:18:13 UTC")
  end

  it "add years" do
    t = Time.utc 2014, 10, 30, 21, 18, 13
    t2 = t + 1.year
    t2.to_s.should eq("2015-10-30 21:18:13 UTC")

    t = Time.utc 2014, 10, 30, 21, 18, 13
    t2 = t - 2.years
    t2.to_s.should eq("2012-10-30 21:18:13 UTC")
  end

  it "add hours" do
    t1 = Time.utc(2002, 2, 25, 15, 25, 13)
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
    t1 = Time.utc(2002, 2, 25, 15, 25, 13)
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
    t1 = Time.utc 2014, 10, 30, 21, 18, 13, nanosecond: 0
    t1.epoch.should eq(1414703893)
    t1.epoch_f.should be_close(1414703893, 1e-01)
  end

  it "gets unix epoch seconds at GMT" do
    t1 = Time.now
    t1.epoch.should eq(t1.to_utc.epoch)
    t1.epoch_f.should be_close(t1.to_utc.epoch_f, 1e-01)
  end

  it "current time is similar in differnt locations" do
    (Time.now - Time.utc_now).should be_close(0.seconds, 1.second)
    (Time.now - Time.now(Time::Location.fixed(1234))).should be_close(0.seconds, 1.second)
  end

  describe "to_s" do
    it "prints local time" do
      with_env("TZ", nil) do
        t = Time.new 2014, 10, 30, 21, 18, 13
        t.to_s.should eq("2014-10-30 21:18:13 #{t.to_s("%:z")}")

        t = Time.new 2014, 1, 30, 21, 18, 13
        t.to_s.should eq("2014-01-30 21:18:13 #{t.to_s("%:z")}")

        t = Time.new 2014, 10, 1, 21, 18, 13
        t.to_s.should eq("2014-10-01 21:18:13 #{t.to_s("%:z")}")

        t = Time.new 2014, 10, 30, 1, 18, 13
        t.to_s.should eq("2014-10-30 01:18:13 #{t.to_s("%:z")}")

        t = Time.new 2014, 10, 30, 21, 1, 13
        t.to_s.should eq("2014-10-30 21:01:13 #{t.to_s("%:z")}")

        t = Time.new 2014, 10, 30, 21, 18, 1
        t.to_s.should eq("2014-10-30 21:18:01 #{t.to_s("%:z")}")
      end
    end

    it "prints without nanoseconds" do
      with_env("TZ", nil) do
        t = Time.new 2014, 10, 30, 21, 18, 13, nanosecond: 12345
        t.to_s.should eq("2014-10-30 21:18:13 #{t.to_s("%:z")}")
      end
    end

    it "prints UTC" do
      t = Time.utc 2014, 10, 30, 21, 18, 13
      t.to_s.should eq("2014-10-30 21:18:13 UTC")
    end

    it "prints zone" do
      with_zoneinfo do
        location = Time::Location.load("Europe/Berlin")
        t = Time.new 2014, 10, 30, 21, 18, 13, location: location
        t.to_s.should eq("2014-10-30 21:18:13 +01:00 Europe/Berlin")

        t = Time.new 2014, 10, 10, 21, 18, 13, location: location
        t.to_s.should eq("2014-10-10 21:18:13 +02:00 Europe/Berlin")
      end
    end

    it "prints offset" do
      t = Time.new 2014, 10, 30, 21, 18, 13, location: Time::Location.fixed(-9000)
      t.to_s.should eq("2014-10-30 21:18:13 -02:30")
    end
  end

  it "formats" do
    with_zoneinfo do
      t = Time.new 2014, 1, 2, 3, 4, 5, nanosecond: 6_000_000
      t2 = Time.new 2014, 1, 2, 15, 4, 5, nanosecond: 6_000_000
      t3 = Time.new 2014, 1, 2, 12, 4, 5, nanosecond: 6_000_000

      t.to_s("%Y").should eq("2014")
      Time.new(1, 1, 2, 3, 4, 5, nanosecond: 6).to_s("%Y").should eq("0001")

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
      t.to_s("%N").to_s.should eq("006000000")
      t.to_s("%3N").to_s.should eq("006")
      t.to_s("%6N").to_s.should eq("006000")
      t.to_s("%9N").to_s.should eq("006000000")

      Time.utc_now.to_s("%z").should eq("+0000")
      Time.utc_now.to_s("%:z").should eq("+00:00")
      Time.utc_now.to_s("%::z").should eq("+00:00:00")

      zoned = Time.new(2017, 11, 24, 13, 5, 6, location: Time::Location.load("Europe/Berlin"))
      zoned.to_s("%z").should eq("+0100")
      zoned.to_s("%:z").should eq("+01:00")
      zoned.to_s("%::z").should eq("+01:00:00")

      zoned = Time.new(2017, 11, 24, 13, 5, 6, location: Time::Location.load("America/Buenos_Aires"))
      zoned.to_s("%z").should eq("-0300")
      zoned.to_s("%:z").should eq("-03:00")
      zoned.to_s("%::z").should eq("-03:00:00")

      offset = Time.new(2017, 11, 24, 13, 5, 6, location: Time::Location.fixed(9000))
      offset.to_s("%z").should eq("+0230")
      offset.to_s("%:z").should eq("+02:30")
      offset.to_s("%::z").should eq("+02:30:00")

      offset = Time.new(2017, 11, 24, 13, 5, 6, location: Time::Location.fixed(9001))
      offset.to_s("%z").should eq("+0230")
      offset.to_s("%:z").should eq("+02:30")
      offset.to_s("%::z").should eq("+02:30:01")

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

      t = Time.utc 2014, 1, 2, 3, 4, 5, nanosecond: 6
      t.to_s("%s").should eq("1388631845")
    end
  end

  it "parses empty" do
    t = Time.parse("", "", Time::Location.local)
    t.year.should eq(1)
    t.month.should eq(1)
    t.day.should eq(1)
    t.hour.should eq(0)
    t.minute.should eq(0)
    t.second.should eq(0)
    t.millisecond.should eq(0)
    t.local?.should be_true
  end

  it "parse fails without time zone" do
    expect_raises(Time::Format::Error, "no default location provided") do
      Time.parse("2017-12-01 20:15:13", "%F %T")
    end
    Time.parse("2017-12-01 20:15:13", "%F %T", Time::Location.local).to_s("%F %T").should eq "2017-12-01 20:15:13"
    Time.parse("2017-12-01 20:15:13 +01:00", "%F %T %:z").to_s("%F %T %:z").should eq "2017-12-01 20:15:13 +01:00"
  end

  it "parses" do
    parse_time("2014", "%Y").year.should eq(2014)
    parse_time("19", "%C").year.should eq(1900)
    parse_time("14", "%y").year.should eq(2014)
    parse_time("09", "%m").month.should eq(9)
    parse_time(" 9", "%_m").month.should eq(9)
    parse_time("9", "%-m").month.should eq(9)
    parse_time("February", "%B").month.should eq(2)
    parse_time("March", "%B").month.should eq(3)
    parse_time("MaRcH", "%B").month.should eq(3)
    parse_time("MaR", "%B").month.should eq(3)
    parse_time("MARCH", "%^B").month.should eq(3)
    parse_time("Mar", "%b").month.should eq(3)
    parse_time("Mar", "%^b").month.should eq(3)
    parse_time("MAR", "%^b").month.should eq(3)
    parse_time("MAR", "%h").month.should eq(3)
    parse_time("MAR", "%^h").month.should eq(3)
    parse_time("2", "%d").day.should eq(2)
    parse_time("02", "%d").day.should eq(2)
    parse_time("02", "%-d").day.should eq(2)
    parse_time(" 2", "%e").day.should eq(2)
    parse_time("9", "%H").hour.should eq(9)
    parse_time(" 9", "%k").hour.should eq(9)
    parse_time("09", "%I").hour.should eq(9)
    parse_time(" 9", "%l").hour.should eq(9)
    parse_time("9pm", "%l%p").hour.should eq(21)
    parse_time("9PM", "%l%P").hour.should eq(21)
    parse_time("09", "%M").minute.should eq(9)
    parse_time("09", "%S").second.should eq(9)
    parse_time("123", "%L").millisecond.should eq(123)
    parse_time("1", "%L").millisecond.should eq(100)
    parse_time("000000321", "%N").nanosecond.should eq(321)
    parse_time("321", "%N").nanosecond.should eq(321000000)
    parse_time("321999", "%3N").nanosecond.should eq(321000000)
    parse_time("321", "%6N").nanosecond.should eq(321000000)
    parse_time("000321999", "%6N").nanosecond.should eq(321000)
    parse_time("000000321999", "%9N").nanosecond.should eq(321)
    parse_time("321", "%9N").nanosecond.should eq(321000000)
    parse_time("3214569879999", "%N").nanosecond.should eq(321456987)
    parse_time("Fri Oct 31 23:00:24 2014", "%c").to_s.should eq("2014-10-31 23:00:24 UTC")
    parse_time("10/31/14", "%D").to_s.should eq("2014-10-31 00:00:00 UTC")
    parse_time("10/31/69", "%D").to_s.should eq("1969-10-31 00:00:00 UTC")
    parse_time("2014-10-31", "%F").to_s.should eq("2014-10-31 00:00:00 UTC")
    parse_time("2014-10-31", "%F").to_s.should eq("2014-10-31 00:00:00 UTC")
    parse_time("10/31/14", "%x").to_s.should eq("2014-10-31 00:00:00 UTC")
    parse_time("10:11:12", "%X").to_s.should eq("0001-01-01 10:11:12 UTC")
    parse_time("11:14:01 PM", "%r").to_s.should eq("0001-01-01 23:14:01 UTC")
    parse_time("11:14", "%R").to_s.should eq("0001-01-01 11:14:00 UTC")
    parse_time("11:12:13", "%T").to_s.should eq("0001-01-01 11:12:13 UTC")
    parse_time("This was done on Friday, October 31, 2014", "This was done on %A, %B %d, %Y").to_s.should eq("2014-10-31 00:00:00 UTC")
    parse_time("今は Friday, October 31, 2014", "今は %A, %B %d, %Y").to_s.should eq("2014-10-31 00:00:00 UTC")
    parse_time("epoch: 1459864667", "epoch: %s").epoch.should eq(1459864667)
    parse_time("epoch: -1459864667", "epoch: %s").epoch.should eq(-1459864667)
  end

  it "parses timezone" do
    patterns = {"%z", "%:z", "%::z"}

    {"+0000", "+00:00", "+00:00:00"}.zip(patterns) do |string, pattern|
      time = Time.parse(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_false
      time.location.fixed?.should be_true
    end

    {"-0000", "-00:00", "-00:00:00"}.zip(patterns) do |string, pattern|
      time = Time.parse(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_false
      time.location.fixed?.should be_true
    end

    {"-0200", "-02:00", "-02:00:00"}.zip(patterns) do |string, pattern|
      time = Time.parse(string, pattern)
      time.offset.should eq -2 * 3600
      time.utc?.should be_false
      time.location.fixed?.should be_true
    end

    {"Z", "Z", "Z"}.zip(patterns) do |string, pattern|
      time = Time.parse(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_true
      time.location.fixed?.should be_true
    end

    {"UTC", "UTC", "UTC"}.zip(patterns) do |string, pattern|
      time = Time.parse(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_true
      time.location.fixed?.should be_true
    end

    time = Time.parse("+04:12:39", "%::z")
    time.offset.should eq 4 * 3600 + 12 * 60 + 39
    time.utc?.should be_false
    time.location.fixed?.should be_true
  end

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
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq -6 * 3600
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 +05:00 hi", "%F %T %z hi")
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq 5 * 3600
    time.to_utc.to_s.should eq("2014-10-31 05:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 -06:00:00 hi", "%F %T %z hi")
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq -6 * 3600
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it do
    time = Time.parse("2014-10-31 10:11:12 -060000 hi", "%F %T %z hi")
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq -6 * 3600
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it "parses centiseconds" do
    time = Time.parse("2016-09-09T17:03:28.45+01:00", "%FT%T.%L%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(450)
    time.nanosecond.should eq(450000000)
  end

  it "parses milliseconds with %L" do
    time = Time.parse("2016-09-09T17:03:28.456+01:00", "%FT%T.%L%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(456)
    time.nanosecond.should eq(456000000)
  end

  it "parses milliseconds with %3N" do
    time = Time.parse("2016-09-09T17:03:28.456+01:00", "%FT%T.%3N%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(456)
    time.nanosecond.should eq(456000000)
  end

  it "parses microseconds with %6N" do
    time = Time.parse("2016-09-09T17:03:28.456789+01:00", "%FT%T.%6N%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(456)
    time.nanosecond.should eq(456789000)
  end

  it "parses nanoseconds" do
    time = Time.parse("2016-09-09T17:03:28.456789123+01:00", "%FT%T.%N%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.nanosecond.should eq(456789123)
  end

  it "parses nanoseconds with %9N" do
    time = Time.parse("2016-09-09T17:03:28.456789123+01:00", "%FT%T.%9N%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.nanosecond.should eq(456789123)
  end

  it "parses discarding additional decimals" do
    time = Time.parse("2016-09-09T17:03:28.456789123999", "%FT%T.%3N", Time::Location::UTC)
    time.nanosecond.should eq(456000000)

    time = Time.parse("2016-09-09T17:03:28.456789123999", "%FT%T.%6N", Time::Location::UTC)
    time.nanosecond.should eq(456789000)

    time = Time.parse("2016-09-09T17:03:28.456789123990", "%FT%T.%9N", Time::Location::UTC)
    time.nanosecond.should eq(456789123)

    time = Time.parse("2016-09-09T17:03:28.456789123999999+01:00", "%FT%T.%N%z")
    time.to_s.should eq("2016-09-09 17:03:28 +01:00")
    time.nanosecond.should eq(456789123)

    time = Time.parse("4567892016-09-09T17:03:28", "%6N%FT%T", Time::Location::UTC)
    time.year.should eq(2016)
    time.nanosecond.should eq(456789000)
  end

  it "parses if some decimals are missing" do
    time = Time.parse("2016-09-09T17:03:28.45+01:00", "%FT%T.%3N%z").to_utc
    time.nanosecond.should eq(450000000)

    time = Time.parse("2016-09-09T17:03:28.45678+01:00", "%FT%T.%6N%z").to_utc
    time.nanosecond.should eq(456780000)

    time = Time.parse("2016-09-09T17:03:28.4567891+01:00", "%FT%T.%9N%z").to_utc
    time.nanosecond.should eq(456789100)
  end

  it "parses the correct amount of digits (#853)" do
    time = Time.parse("20150624", "%Y%m%d", Time::Location::UTC)
    time.year.should eq(2015)
    time.month.should eq(6)
    time.day.should eq(24)
  end

  it "parses month blank padded" do
    time = Time.parse("2015 624", "%Y%_m%d", Time::Location::UTC)
    time.year.should eq(2015)
    time.month.should eq(6)
    time.day.should eq(24)
  end

  it "parses day of month blank padded" do
    time = Time.parse("201506 4", "%Y%m%e", Time::Location::UTC)
    time.year.should eq(2015)
    time.month.should eq(6)
    time.day.should eq(4)
  end

  it "parses hour 24 blank padded" do
    time = Time.parse(" 31112", "%k%M%S", Time::Location::UTC)
    time.hour.should eq(3)
    time.minute.should eq(11)
    time.second.should eq(12)
  end

  it "parses hour 12 blank padded" do
    time = Time.parse(" 31112", "%l%M%S", Time::Location::UTC)
    time.hour.should eq(3)
    time.minute.should eq(11)
    time.second.should eq(12)
  end

  it "can parse in location" do
    with_zoneinfo do
      time = Time.parse("2014-10-31 11:12:13", "%F %T", Time::Location::UTC)
      time.utc?.should be_true

      location = Time::Location.load("Europe/Berlin")
      time = Time.parse("2016-11-24 14:32:02", "%F %T", location)
      time.location.should eq location

      time = Time.parse("2016-11-24 14:32:02 +01:00", "%F %T %:z", location)
      time.location.should eq Time::Location.fixed(3600)
    end
  end

  it "at" do
    t1 = Time.new 2014, 11, 25, 10, 11, 12, nanosecond: 13
    t2 = Time.new 2014, 6, 25, 10, 11, 12, nanosecond: 13

    t1.at_beginning_of_year.to_s("%F %T").should eq("2014-01-01 00:00:00")

    1.upto(3) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s("%F %T").should eq("2014-01-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s("%F %T").should eq("2014-03-31 23:59:59")
    end
    4.upto(6) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s("%F %T").should eq("2014-04-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s("%F %T").should eq("2014-06-30 23:59:59")
    end
    7.upto(9) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s("%F %T").should eq("2014-07-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s("%F %T").should eq("2014-09-30 23:59:59")
    end
    10.upto(12) do |i|
      Time.new(2014, i, 10).at_beginning_of_quarter.to_s("%F %T").should eq("2014-10-01 00:00:00")
      Time.new(2014, i, 10).at_end_of_quarter.to_s("%F %T").should eq("2014-12-31 23:59:59")
    end

    t1.at_beginning_of_quarter.to_s("%F %T").should eq("2014-10-01 00:00:00")
    t1.at_beginning_of_month.to_s("%F %T").should eq("2014-11-01 00:00:00")

    3.upto(9) do |i|
      Time.new(2014, 11, i).at_beginning_of_week.to_s("%F %T").should eq("2014-11-03 00:00:00")
    end

    t1.at_beginning_of_day.to_s("%F %T").should eq("2014-11-25 00:00:00")
    t1.at_beginning_of_hour.to_s("%F %T").should eq("2014-11-25 10:00:00")
    t1.at_beginning_of_minute.to_s("%F %T").should eq("2014-11-25 10:11:00")

    t1.at_end_of_year.to_s("%F %T").should eq("2014-12-31 23:59:59")

    t1.at_end_of_quarter.to_s("%F %T").should eq("2014-12-31 23:59:59")
    t2.at_end_of_quarter.to_s("%F %T").should eq("2014-06-30 23:59:59")

    t1.at_end_of_month.to_s("%F %T").should eq("2014-11-30 23:59:59")
    t1.at_end_of_week.to_s("%F %T").should eq("2014-11-30 23:59:59")

    Time.new(2014, 11, 2).at_end_of_week.to_s("%F %T").should eq("2014-11-02 23:59:59")
    3.upto(9) do |i|
      Time.new(2014, 11, i).at_end_of_week.to_s("%F %T").should eq("2014-11-09 23:59:59")
    end

    t1.at_end_of_day.to_s("%F %T").should eq("2014-11-25 23:59:59")
    t1.at_end_of_hour.to_s("%F %T").should eq("2014-11-25 10:59:59")
    t1.at_end_of_minute.to_s("%F %T").should eq("2014-11-25 10:11:59")

    t1.at_midday.to_s("%F %T").should eq("2014-11-25 12:00:00")

    t1.at_beginning_of_semester.to_s("%F %T").should eq("2014-07-01 00:00:00")
    t2.at_beginning_of_semester.to_s("%F %T").should eq("2014-01-01 00:00:00")

    t1.at_end_of_semester.to_s("%F %T").should eq("2014-12-31 23:59:59")
    t2.at_end_of_semester.to_s("%F %T").should eq("2014-06-30 23:59:59")
  end

  it "does time span units" do
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
  end

  it "preserves location when adding" do
    time = Time.utc_now
    time.utc?.should be_true

    (time + 5.minutes).utc?.should be_true

    time = Time.now
    (time + 5.minutes).location.should eq time.location
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

  it "compares different locations" do
    time = Time.now
    (time.to_utc <=> time).should eq(0)
  end

  it "does diff of utc vs local time" do
    local = Time.now
    utc = local.to_utc
    (utc - local).should eq(0.seconds)
    (local - utc).should eq(0.seconds)
  end

  describe "#in" do
    it "changes location" do
      location = Time::Location.fixed(3600)
      location2 = Time::Location.fixed(12345)
      time1 = Time.now(location)
      time1.location.should eq(location)

      time2 = time1.in(location2)
      time2.should eq(time1)
      time2.location.should eq(location2)
    end
  end

  it "#to_s" do
    with_zoneinfo do
      time = Time.new(2017, 11, 25, 22, 6, 17, location: Time::Location::UTC)
      time.to_s.should eq "2017-11-25 22:06:17 UTC"

      time = Time.new(2017, 11, 25, 22, 6, 17, location: Time::Location.fixed(-7200))
      time.to_s.should eq "2017-11-25 22:06:17 -02:00"

      time = Time.new(2017, 11, 25, 22, 6, 17, location: Time::Location.fixed(-7259))
      time.to_s.should eq "2017-11-25 22:06:17 -02:00:59"

      location = Time::Location.load("Europe/Berlin")
      time = Time.new(2017, 11, 25, 22, 6, 17, location: location)
      time.to_s.should eq "2017-11-25 22:06:17 +01:00 Europe/Berlin"
    end
  end

  describe "days in month" do
    it "returns days for valid month and year" do
      Time.days_in_month(2016, 2).should eq(29)
      Time.days_in_month(1990, 4).should eq(30)
    end

    it "raises exception for invalid month" do
      expect_raises(ArgumentError, "Invalid month") do
        Time.days_in_month(2016, 13)
      end
    end

    it "raises exception for invalid year" do
      expect_raises(ArgumentError, "Invalid year") do
        Time.days_in_month(10000, 11)
      end
    end
  end

  it "days in year with year" do
    Time.days_in_year(2005).should eq(365)
    Time.days_in_year(2004).should eq(366)
    Time.days_in_year(2000).should eq(366)
    Time.days_in_year(1990).should eq(365)
  end

  typeof(Time.now.year)
  typeof(1.minute.from_now.year)
  typeof(1.minute.ago.year)
  typeof(1.month.from_now.year)
  typeof(1.month.ago.year)
  typeof(Time.now.to_utc)
  typeof(Time.now.to_local)
end

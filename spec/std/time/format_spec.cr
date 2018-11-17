require "./spec_helper"

def parse_time(format, string)
  Time.parse_utc(format, string)
end

def parse_time(string)
  Time.parse_utc(string, "%F %T.%N")
end

describe Time::Format do
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

      Time.utc(1985, 4, 12).to_s("%G-W%V-%u").should eq "1985-W15-5"
      Time.utc(2005, 1, 1).to_s("%G-W%V-%u").should eq "2004-W53-6"
      Time.utc(2005, 1, 2).to_s("%G-W%V-%u").should eq "2004-W53-7"
      Time.utc(2005, 12, 31).to_s("%G-W%V-%u").should eq "2005-W52-6"
      Time.utc(2006, 1, 1).to_s("%G-W%V-%u").should eq "2005-W52-7"
      Time.utc(2006, 1, 2).to_s("%G-W%V-%u").should eq "2006-W01-1"
      Time.utc(2006, 12, 31).to_s("%G-W%V-%u").should eq "2006-W52-7"
      Time.utc(2007, 1, 1).to_s("%G-W%V-%u").should eq "2007-W01-1"
      Time.utc(2007, 12, 30).to_s("%G-W%V-%u").should eq "2007-W52-7"
      Time.utc(2007, 12, 31).to_s("%G-W%V-%u").should eq "2008-W01-1"
      Time.utc(2008, 1, 1).to_s("%G-W%V-%u").should eq "2008-W01-2"
      Time.utc(2008, 12, 28).to_s("%G-W%V-%u").should eq "2008-W52-7"
      Time.utc(2008, 12, 29).to_s("%G-W%V-%u").should eq "2009-W01-1"
      Time.utc(2008, 12, 30).to_s("%G-W%V-%u").should eq "2009-W01-2"
      Time.utc(2008, 12, 31).to_s("%G-W%V-%u").should eq "2009-W01-3"
      Time.utc(2009, 1, 1).to_s("%G-W%V-%u").should eq "2009-W01-4"
      Time.utc(2009, 12, 31).to_s("%G-W%V-%u").should eq "2009-W53-4"
      Time.utc(2010, 1, 1).to_s("%G-W%V-%u").should eq "2009-W53-5"
      Time.utc(2010, 1, 2).to_s("%G-W%V-%u").should eq "2009-W53-6"
      Time.utc(2010, 1, 3).to_s("%G-W%V-%u").should eq "2009-W53-7"
      Time.utc(1985, 4, 12).to_s("%g-W%V-%u").should eq "85-W15-5"
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

  it "formats standard formats" do
    time = Time.utc(2016, 2, 15)
    time.to_rfc3339.should eq "2016-02-15T00:00:00Z"
    Time.parse_rfc3339(time.to_rfc3339).should eq time
    time.to_rfc2822.should eq "Mon, 15 Feb 2016 00:00:00 +0000"
    Time.parse_rfc2822(time.to_rfc2822).should eq time
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
      Time.parse!("2017-12-01 20:15:13", "%F %T")
    end
    Time.parse("2017-12-01 20:15:13", "%F %T", Time::Location.local).to_s("%F %T").should eq "2017-12-01 20:15:13"
    Time.parse!("2017-12-01 20:15:13 +01:00", "%F %T %:z").to_s("%F %T %:z").should eq "2017-12-01 20:15:13 +01:00"
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
    parse_time("epoch: 1459864667", "epoch: %s").to_unix.should eq(1459864667)
    parse_time("epoch: -1459864667", "epoch: %s").to_unix.should eq(-1459864667)

    parse_time("1985-W15-5", "%G-W%V-%u").should eq(Time.utc(1985, 4, 12))
    parse_time("2004-W53-6", "%G-W%V-%u").should eq(Time.utc(2005, 1, 1))
    parse_time("2004-W53-7", "%G-W%V-%u").should eq(Time.utc(2005, 1, 2))
    parse_time("2005-W52-6", "%G-W%V-%u").should eq(Time.utc(2005, 12, 31))
    parse_time("2005-W52-7", "%G-W%V-%u").should eq(Time.utc(2006, 1, 1))
    parse_time("2006-W01-1", "%G-W%V-%u").should eq(Time.utc(2006, 1, 2))
    parse_time("2006-W52-7", "%G-W%V-%u").should eq(Time.utc(2006, 12, 31))
    parse_time("2007-W01-1", "%G-W%V-%u").should eq(Time.utc(2007, 1, 1))
    parse_time("2007-W52-7", "%G-W%V-%u").should eq(Time.utc(2007, 12, 30))
    parse_time("2008-W01-1", "%G-W%V-%u").should eq(Time.utc(2007, 12, 31))
    parse_time("2008-W01-2", "%G-W%V-%u").should eq(Time.utc(2008, 1, 1))
    parse_time("2008-W52-7", "%G-W%V-%u").should eq(Time.utc(2008, 12, 28))
    parse_time("2009-W01-1", "%G-W%V-%u").should eq(Time.utc(2008, 12, 29))
    parse_time("2009-W01-2", "%G-W%V-%u").should eq(Time.utc(2008, 12, 30))
    parse_time("2009-W01-3", "%G-W%V-%u").should eq(Time.utc(2008, 12, 31))
    parse_time("2009-W01-4", "%G-W%V-%u").should eq(Time.utc(2009, 1, 1))
    parse_time("2009-W53-4", "%G-W%V-%u").should eq(Time.utc(2009, 12, 31))
    parse_time("2009-W53-5", "%G-W%V-%u").should eq(Time.utc(2010, 1, 1))
    parse_time("2009-W53-6", "%G-W%V-%u").should eq(Time.utc(2010, 1, 2))
    parse_time("2009-W53-7", "%G-W%V-%u").should eq(Time.utc(2010, 1, 3))
  end

  it "parses timezone" do
    patterns = {"%z", "%:z", "%::z"}

    {"+0000", "+00:00", "+00:00:00"}.zip(patterns) do |string, pattern|
      time = Time.parse!(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_false
      time.location.fixed?.should be_true
    end

    {"-0000", "-00:00", "-00:00:00"}.zip(patterns) do |string, pattern|
      time = Time.parse!(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_false
      time.location.fixed?.should be_true
    end

    {"-0200", "-02:00", "-02:00:00"}.zip(patterns) do |string, pattern|
      time = Time.parse!(string, pattern)
      time.offset.should eq -2 * 3600
      time.utc?.should be_false
      time.location.fixed?.should be_true
    end

    {"Z", "Z", "Z"}.zip(patterns) do |string, pattern|
      time = Time.parse!(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_true
      time.location.fixed?.should be_true
    end

    {"UTC", "UTC", "UTC"}.zip(patterns) do |string, pattern|
      time = Time.parse!(string, pattern)
      time.offset.should eq 0
      time.utc?.should be_true
      time.location.fixed?.should be_true
    end

    time = Time.parse!("+04:12:39", "%::z")
    time.offset.should eq 4 * 3600 + 12 * 60 + 39
    time.utc?.should be_false
    time.location.fixed?.should be_true

    time = Time.parse!("-04:12:39", "%::z")
    time.offset.should eq -1 * (4 * 3600 + 12 * 60 + 39)
    time.utc?.should be_false
    time.location.fixed?.should be_true
  end

  it "raises when time zone missing" do
    expect_raises(Time::Format::Error, "Invalid timezone") do
      Time.parse!("", "%z")
    end
    expect_raises(Time::Format::Error, "Invalid timezone") do
      Time.parse!("123456+01:00", "%3N%z")
    end
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
    time = Time.parse!("2014-10-31 10:11:12 Z hi", "%F %T %z hi")
    time.utc?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 10:11:12 UTC")
  end

  it do
    time = Time.parse!("2014-10-31 10:11:12 UTC hi", "%F %T %z hi")
    time.utc?.should be_true
    time.to_utc.to_s.should eq("2014-10-31 10:11:12 UTC")
  end

  it do
    time = Time.parse!("2014-10-31 10:11:12 -06:00 hi", "%F %T %z hi")
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq -6 * 3600
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it do
    time = Time.parse!("2014-10-31 10:11:12 +05:00 hi", "%F %T %z hi")
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq 5 * 3600
    time.to_utc.to_s.should eq("2014-10-31 05:11:12 UTC")
  end

  it do
    time = Time.parse!("2014-10-31 10:11:12 -06:00:00 hi", "%F %T %z hi")
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq -6 * 3600
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it do
    time = Time.parse!("2014-10-31 10:11:12 -060000 hi", "%F %T %z hi")
    time.utc?.should be_false
    time.location.fixed?.should be_true
    time.offset.should eq -6 * 3600
    time.to_utc.to_s.should eq("2014-10-31 16:11:12 UTC")
  end

  it "parses centiseconds" do
    time = Time.parse!("2016-09-09T17:03:28.45+01:00", "%FT%T.%L%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(450)
    time.nanosecond.should eq(450000000)
  end

  it "parses milliseconds with %L" do
    time = Time.parse!("2016-09-09T17:03:28.456+01:00", "%FT%T.%L%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(456)
    time.nanosecond.should eq(456000000)
  end

  it "parses milliseconds with %3N" do
    time = Time.parse!("2016-09-09T17:03:28.456+01:00", "%FT%T.%3N%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(456)
    time.nanosecond.should eq(456000000)
  end

  it "parses microseconds with %6N" do
    time = Time.parse!("2016-09-09T17:03:28.456789+01:00", "%FT%T.%6N%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.millisecond.should eq(456)
    time.nanosecond.should eq(456789000)
  end

  it "parses nanoseconds" do
    time = Time.parse!("2016-09-09T17:03:28.456789123+01:00", "%FT%T.%N%z").to_utc
    time.to_s.should eq("2016-09-09 16:03:28 UTC")
    time.nanosecond.should eq(456789123)
  end

  it "parses nanoseconds with %9N" do
    time = Time.parse!("2016-09-09T17:03:28.456789123+01:00", "%FT%T.%9N%z").to_utc
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

    time = Time.parse!("2016-09-09T17:03:28.456789123999999+01:00", "%FT%T.%N%z")
    time.to_s.should eq("2016-09-09 17:03:28 +01:00")
    time.nanosecond.should eq(456789123)

    time = Time.parse("4567892016-09-09T17:03:28", "%6N%FT%T", Time::Location::UTC)
    time.year.should eq(2016)
    time.nanosecond.should eq(456789000)
  end

  it "parses if some decimals are missing" do
    time = Time.parse!("2016-09-09T17:03:28.45+01:00", "%FT%T.%3N%z").to_utc
    time.nanosecond.should eq(450000000)

    time = Time.parse!("2016-09-09T17:03:28.45678+01:00", "%FT%T.%6N%z").to_utc
    time.nanosecond.should eq(456780000)

    time = Time.parse!("2016-09-09T17:03:28.4567891+01:00", "%FT%T.%9N%z").to_utc
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
end

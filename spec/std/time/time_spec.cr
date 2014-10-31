#!/usr/bin/env bin/crystal --run
require "spec"

TimeSpecTicks = [
  631501920000000000_i64, # 25 Feb 2002 - 00:00:00
  631502475130080000_i64, # 25 Feb 2002 - 15:25:13,8
  631502115130080000_i64, # 25 Feb 2002 - 05:25:13,8
  631502115000000000_i64, # 25 Feb 2002 - 05:25:00
  631502115130000000_i64, # 25 Feb 2002 - 05:25:13
  631502079130000000_i64, # 25 Feb 2002 - 04:25:13
  629197085770000000_i64, # 06 Nov 1994 - 08:49:37
  631796544000000000_i64, # 01 Feb 2003 - 00:00:00
]

def Time.expect_invalid
  expect_raises ArgumentError, "invalid time" do
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

  it "fields" do
    Time::MaxValue.ticks.should eq(3155378975999999999)
    Time::MinValue.ticks.should eq(0)
  end

  it "add" do
    t1 = Time.new TimeSpecTicks[1]
    span = TimeSpan.new 3, 54, 1
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

    t = Time.new 2014, 10, 31, 21, 18, 13
    t2 = t + 1.month
    t2.to_s.should eq("2014-11-30 21:18:13")

    t = Time.new 2014, 10, 31, 21, 18, 13
    t2 = t - 1.month
    t2.to_s.should eq("2014-09-30 21:18:13")
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
    t.time_of_day.should eq(TimeSpan.new(21, 18, 13))
  end

  it "gets day of week" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.day_of_week.should eq(4)
  end

  it "gets day of week" do
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

    t.to_s("%Y").should eq("2014")
    t.to_s("%C").should eq("20")
    t.to_s("%y").should eq("14")
    t.to_s("%m").should eq("01")
    t.to_s("%_m").should eq(" 1")
    t.to_s("%-m").should eq("1")
    t.to_s("%B").should eq("February")
    t.to_s("%^B").should eq("FEBRUARY")
    t.to_s("%b").should eq("Feb")
    t.to_s("%^b").should eq("FEB")
    t.to_s("%h").should eq("Feb")
    t.to_s("%^h").should eq("FEB")
    t.to_s("%d").should eq("02")
    t.to_s("%-d").should eq("2")
    t.to_s("%e").should eq(" 2")
    t.to_s("%j").should eq("002")
    t.to_s("%H").should eq("03")

    t.to_s("%k").should eq(" 3")
    t2.to_s("%k").should eq("15")

    t.to_s("%I").should eq("03")
    t2.to_s("%I").should eq("03")

    t.to_s("%l").should eq(" 3")
    t2.to_s("%l").should eq(" 3")

    # Note: we purposely match %p to am/pm and %P to AM/PM (makes more sense)
    t.to_s("%p").should eq("am")
    t2.to_s("%p").should eq("pm")

    t.to_s("%P").should eq("AM")
    t2.to_s("%P").should eq("PM")

    t.to_s("%M").to_s.should eq("04")
    t.to_s("%S").to_s.should eq("05")
    t.to_s("%L").to_s.should eq("006")

    # TODO %N
    # TODO %z
    # TODO %Z

    t.to_s("%A").to_s.should eq("Thursday")
    t.to_s("%^A").to_s.should eq("THURSDAY")
    t.to_s("%a").to_s.should eq("Thu")
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
  end
end

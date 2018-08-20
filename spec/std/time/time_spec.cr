require "./spec_helper"

describe Time do
  describe ".new" do
    it "initializes" do
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

    it "initializes max value" do
      time = Time.new(9999, 12, 31, 23, 59, 59, nanosecond: 999_999_999)
      time.year.should eq(9999)
      time.month.should eq(12)
      time.day.should eq(31)
      time.hour.should eq(23)
      time.minute.should eq(59)
      time.second.should eq(59)
      time.nanosecond.should eq(999_999_999)
    end

    it "fails with negative nanosecond" do
      expect_raises ArgumentError, "Invalid time" do
        Time.new(9999, 12, 31, 23, 59, 59, nanosecond: -1)
      end
    end

    it "fails with too big nanoseconds" do
      expect_raises ArgumentError, "Invalid time" do
        Time.new(9999, 12, 31, 23, 59, 59, nanosecond: 1_000_000_000)
      end
    end

    it "checks boundary at time min" do
      {-5 * 3600, -1, 0, 1, 5 * 3600}.each do |offset|
        seconds = -offset.to_i64
        location = Time::Location.fixed(offset)
        Time.new(seconds: seconds + 1, nanoseconds: 0, location: location)
        Time.new(seconds: seconds, nanoseconds: 0, location: location)
        expect_raises ArgumentError, "Invalid time" do
          Time.new(seconds: seconds - 1, nanoseconds: 0, location: location)
        end
      end
    end

    it "checks boundary at time max" do
      {-5 * 3600, -1, 0, 1, 5 * 3600}.each do |offset|
        seconds = Time::MAX_SECONDS - offset.to_i64
        location = Time::Location.fixed(offset)
        Time.new(seconds: seconds - 1, nanoseconds: 0, location: location)
        Time.new(seconds: seconds, nanoseconds: 0, location: location)
        expect_raises ArgumentError, "Invalid time" do
          Time.new(seconds: seconds + 1, nanoseconds: 0, location: location)
        end
      end
    end
  end

  it ".epoch" do
    seconds = 1439404155
    time = Time.epoch(seconds)
    time.should eq(Time.utc(2015, 8, 12, 18, 29, 15))
    time.epoch.should eq(seconds)
    time.utc?.should be_true
  end

  it ".epoch_ms" do
    milliseconds = 1439404155000
    time = Time.epoch_ms(milliseconds)
    time.should eq(Time.utc(2015, 8, 12, 18, 29, 15))
    time.epoch_ms.should eq(milliseconds)
    time.utc?.should be_true
  end

  describe ".now" do
    it "current time is similar in differnt locations" do
      (Time.now - Time.utc_now).should be_close(0.seconds, 1.second)
      (Time.now - Time.now(Time::Location.fixed(1234))).should be_close(0.seconds, 1.second)
    end
  end

  describe ".monotonic" do
    it "returns always increasing monotonic clock" do
      clock = Time.monotonic
      Time.monotonic.should be >= clock
    end
  end

  describe ".measure" do
    it "measures elapsed time" do
      # NOTE: On some systems, the sleep may not always wait for 1ms and the fiber
      #       be resumed early. We thus merely test that the method returns a
      #       positive time span.
      elapsed = Time.measure { sleep 1.millisecond }
      elapsed.should be >= 0.seconds
    end
  end

  it "#clone" do
    time = Time.now
    (time == time.clone).should be_true
  end

  describe "#add_span" do
    it "adds hours, minutes, seconds" do
      t1 = Time.utc(2002, 2, 25, 15, 25, 13)
      t2 = t1 + Time::Span.new 3, 54, 1

      t2.should eq Time.utc(2002, 2, 25, 19, 19, 14)
    end

    it "raises out of range min" do
      t1 = Time.utc(9980, 2, 25, 15, 25, 13)

      expect_raises ArgumentError do
        t1 + Time::Span.new(nanoseconds: Int64::MAX)
      end
    end

    it "raises out of range max" do
      t1 = Time.utc(1, 2, 25, 15, 25, 13)

      expect_raises ArgumentError do
        t1 + Time::Span.new(nanoseconds: Int64::MIN)
      end
    end

    it "checks boundary at time min" do
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

    it "checks boundary at time max" do
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

    describe "adds days" do
      it "simple" do
        time = Time.utc(2002, 2, 25, 15, 25, 13)
        time = time + 3.days

        time.should eq Time.utc(2002, 2, 28, 15, 25, 13)

        time = time + 1.9.days
        time.should eq Time.utc(2002, 3, 2, 13, 1, 13)

        time = time + 0.2.days
        time.should eq Time.utc(2002, 3, 2, 17, 49, 13)
      end

      pending "over dst" do
        with_zoneinfo do
          location = Time::Location.load("Europe/Berlin")
          reference = Time.new(2017, 10, 28, 13, 37, location: location)
          next_day = Time.new(2017, 10, 29, 13, 37, location: location)

          (reference + 1.day).should eq next_day
        end
      end

      it "out of range max" do
        time = Time.utc(2002, 2, 25, 15, 25, 13)
        expect_raises ArgumentError do
          time + 10000000.days
        end
      end

      it "out of range min" do
        time = Time.utc(2002, 2, 25, 15, 25, 13)
        expect_raises ArgumentError do
          time - 10000000.days
        end
      end
    end

    it "adds months" do
      t = Time.utc 2014, 10, 30, 21, 18, 13

      t2 = t + 1.month
      t2.should eq Time.utc(2014, 11, 30, 21, 18, 13)

      t2 = t + 1.months
      t2.should eq Time.utc(2014, 11, 30, 21, 18, 13)

      t = Time.utc 2014, 10, 31, 21, 18, 13
      t2 = t + 1.month
      t2.should eq Time.utc(2014, 11, 30, 21, 18, 13)

      t = Time.utc 2014, 10, 31, 21, 18, 13
      t2 = t - 1.month
      t2.should eq Time.utc(2014, 9, 30, 21, 18, 13)

      t = Time.utc 2014, 10, 31, 21, 18, 13
      t2 = t + 6.month
      t2.should eq Time.utc(2015, 4, 30, 21, 18, 13)
    end

    it "adds years" do
      t = Time.utc 2014, 10, 30, 21, 18, 13

      t2 = t + 1.year
      t2.should eq Time.utc(2015, 10, 30, 21, 18, 13)

      t = Time.utc 2014, 10, 30, 21, 18, 13
      t2 = t - 2.years
      t2.should eq Time.utc(2012, 10, 30, 21, 18, 13)
    end

    it "adds hours" do
      time = Time.utc(2002, 2, 25, 15, 25, 13)

      time = time + 10.hours
      time.should eq Time.utc(2002, 2, 26, 1, 25, 13)

      time = time - 3.7.hours
      time.should eq Time.utc(2002, 2, 25, 21, 43, 13)

      time = time + 3.732.hours
      time.should eq Time.utc(2002, 2, 26, 1, 27, 8, nanosecond: 200_000_000)
    end

    it "adds nanoseconds" do
      time = Time.utc(2002, 2, 25, 15, 25, 13)
      time = time + 1e16.nanoseconds
      time.should eq Time.utc(2002, 6, 21, 9, 11, 53)

      time = time - 19e16.nanoseconds
      time.should eq Time.utc(1996, 6, 13, 7, 25, 13)

      time = time + 15_623_487.nanoseconds
      time.should eq Time.utc(1996, 6, 13, 7, 25, 13, nanosecond: 15_623_487)
    end

    it "preserves location when adding" do
      time = Time.utc_now
      time.utc?.should be_true

      (time + 5.minutes).utc?.should be_true

      time = Time.now
      (time + 5.minutes).location.should eq time.location
    end
  end

  it "#time_of_day" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.time_of_day.should eq(Time::Span.new(21, 18, 13))
  end

  it "#day_of_week" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.day_of_week.should eq(Time::DayOfWeek::Thursday)
  end

  it "answers day name predicates" do
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

  it "#day_of_year" do
    t = Time.new 2014, 10, 30, 21, 18, 13
    t.day_of_year.should eq(303)
  end

  describe "#<=>" do
    it "compares" do
      t1 = Time.new 2014, 10, 30, 21, 18, 13
      t2 = Time.new 2014, 10, 30, 21, 18, 14

      (t1 <=> t2).should eq(-1)
      (t1 == t2).should be_false
      (t1 < t2).should be_true
    end

    it "compares different locations" do
      time = Time.now
      (time.to_utc <=> time).should eq(0)
    end
  end

  describe "#epoch" do
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
  end

  describe "#to_s" do
    it "prints string" do
      with_zoneinfo do
        time = Time.new(2017, 11, 25, 22, 6, 17, location: Time::Location::UTC)
        time.to_s.should eq "2017-11-25 22:06:17 UTC"

        time = Time.new(2017, 11, 25, 22, 6, 17, location: Time::Location.fixed(-7200))
        time.to_s.should eq "2017-11-25 22:06:17 -02:00"

        time = Time.new(2017, 11, 25, 22, 6, 17, location: Time::Location.fixed(-7259))
        time.to_s.should eq "2017-11-25 22:06:17 -02:00:59"

        location = Time::Location.load("Europe/Berlin")
        time = Time.new(2017, 11, 25, 22, 6, 17, location: location)
        time.to_s.should eq "2017-11-25 22:06:17 +01:00"
      end
    end

    it "prints date-time fields" do
      Time.utc(2014, 1, 30, 21, 18, 13).to_s.should eq("2014-01-30 21:18:13 UTC")
      Time.utc(2014, 10, 1, 21, 18, 13).to_s.should eq("2014-10-01 21:18:13 UTC")
      Time.utc(2014, 10, 30, 1, 18, 13).to_s.should eq("2014-10-30 01:18:13 UTC")
      Time.utc(2014, 10, 30, 21, 1, 13).to_s.should eq("2014-10-30 21:01:13 UTC")
      Time.utc(2014, 10, 30, 21, 18, 1).to_s.should eq("2014-10-30 21:18:01 UTC")
    end

    it "omits nanoseconds" do
      Time.utc(2014, 10, 30, 21, 18, 13).to_s.should eq("2014-10-30 21:18:13 UTC")
      Time.utc(2014, 10, 30, 21, 18, 13, nanosecond: 12345).to_s.should eq("2014-10-30 21:18:13 UTC")
    end

    it "prints offset for location" do
      with_zoneinfo do
        location = Time::Location.load("Europe/Berlin")
        Time.new(2014, 10, 30, 21, 18, 13, location: location).to_s.should eq("2014-10-30 21:18:13 +01:00")
        Time.new(2014, 10, 30, 21, 18, 13, nanosecond: 123_456, location: location).to_s.should eq("2014-10-30 21:18:13 +01:00")

        Time.new(2014, 10, 10, 21, 18, 13, location: location).to_s.should eq("2014-10-10 21:18:13 +02:00")
        Time.new(2014, 10, 10, 21, 18, 13, nanosecond: 123_456, location: location).to_s.should eq("2014-10-10 21:18:13 +02:00")
      end
    end

    it "prints offset for fixed location" do
      location = Time::Location.fixed(3601)
      Time.new(2014, 1, 2, 3, 4, 5, location: location).to_s.should eq "2014-01-02 03:04:05 +01:00:01"
      Time.new(2014, 1, 2, 3, 4, 5, nanosecond: 123_456_789, location: location).to_s.should eq "2014-01-02 03:04:05 +01:00:01"

      t = Time.new 2014, 10, 30, 21, 18, 13, location: Time::Location.fixed(-9000)
      t.to_s.should eq("2014-10-30 21:18:13 -02:30")
    end

    it "prints local time" do
      # Simulates loading non-fixed offset local time from /etc/localtime
      old_local = Time::Location.local
      begin
        location = Time::Location.new "Local", [Time::Location::Zone.new("STZ", 3600, false), Time::Location::Zone.new("DTZ", -3600, false)], [] of Time::Location::ZoneTransition
        Time::Location.local = location

        Time.new(2014, 10, 30, 21, 18, 13).to_s.should eq("2014-10-30 21:18:13 +01:00")
      ensure
        Time::Location.local = old_local
      end
    end
  end

  it "#inspect" do
    Time.utc(2014, 1, 2, 3, 4, 5).inspect.should eq "2014-01-02 03:04:05.0 UTC"
    Time.utc(2014, 1, 2, 3, 4, 5, nanosecond: 123_456_789).inspect.should eq "2014-01-02 03:04:05.123456789 UTC"

    with_zoneinfo do
      location = Time::Location.load("Europe/Berlin")
      Time.new(2014, 1, 2, 3, 4, 5, location: location).inspect.should eq "2014-01-02 03:04:05.0 +01:00 Europe/Berlin"
      Time.new(2014, 1, 2, 3, 4, 5, nanosecond: 123_456_789, location: location).inspect.should eq "2014-01-02 03:04:05.123456789 +01:00 Europe/Berlin"
    end

    location = Time::Location.fixed(3601)
    Time.new(2014, 1, 2, 3, 4, 5, location: location).inspect.should eq "2014-01-02 03:04:05.0 +01:00:01"
    Time.new(2014, 1, 2, 3, 4, 5, nanosecond: 123_456_789, location: location).inspect.should eq "2014-01-02 03:04:05.123456789 +01:00:01"
  end

  it "at methods" do
    t1 = Time.utc 2014, 11, 25, 10, 11, 12, nanosecond: 13
    t2 = Time.utc 2014, 6, 25, 10, 11, 12, nanosecond: 13

    t1.at_beginning_of_year.should eq Time.utc(2014, 1, 1)

    1.upto(3) do |i|
      Time.utc(2014, i, 10).at_beginning_of_quarter.should eq Time.utc(2014, 1, 1)
      Time.utc(2014, i, 10).at_end_of_quarter.should eq Time.utc(2014, 3, 31, 23, 59, 59, nanosecond: 999_999_999)
    end
    4.upto(6) do |i|
      Time.utc(2014, i, 10).at_beginning_of_quarter.should eq Time.utc(2014, 4, 1)
      Time.utc(2014, i, 10).at_end_of_quarter.should eq Time.utc(2014, 6, 30, 23, 59, 59, nanosecond: 999_999_999)
    end
    7.upto(9) do |i|
      Time.utc(2014, i, 10).at_beginning_of_quarter.should eq Time.utc(2014, 7, 1)
      Time.utc(2014, i, 10).at_end_of_quarter.should eq Time.utc(2014, 9, 30, 23, 59, 59, nanosecond: 999_999_999)
    end
    10.upto(12) do |i|
      Time.utc(2014, i, 10).at_beginning_of_quarter.should eq Time.utc(2014, 10, 1)
      Time.utc(2014, i, 10).at_end_of_quarter.should eq Time.utc(2014, 12, 31, 23, 59, 59, nanosecond: 999_999_999)
    end

    t1.at_beginning_of_quarter.should eq Time.utc(2014, 10, 1)
    t1.at_beginning_of_month.should eq Time.utc(2014, 11, 1)

    3.upto(9) do |i|
      Time.utc(2014, 11, i).at_beginning_of_week.should eq Time.utc(2014, 11, 3)
    end

    t1.at_beginning_of_day.should eq Time.utc(2014, 11, 25)
    t1.at_beginning_of_hour.should eq Time.utc(2014, 11, 25, 10)
    t1.at_beginning_of_minute.should eq Time.utc(2014, 11, 25, 10, 11)
    t1.at_beginning_of_second.should eq Time.utc(2014, 11, 25, 10, 11, 12)

    t1.at_end_of_year.should eq Time.utc(2014, 12, 31, 23, 59, 59, nanosecond: 999_999_999)

    t1.at_end_of_quarter.should eq Time.utc(2014, 12, 31, 23, 59, 59, nanosecond: 999_999_999)
    t2.at_end_of_quarter.should eq Time.utc(2014, 6, 30, 23, 59, 59, nanosecond: 999_999_999)

    t1.at_end_of_month.should eq Time.utc(2014, 11, 30, 23, 59, 59, nanosecond: 999_999_999)
    t1.at_end_of_week.should eq Time.utc(2014, 11, 30, 23, 59, 59, nanosecond: 999_999_999)

    Time.utc(2014, 11, 2).at_end_of_week.should eq Time.utc(2014, 11, 2, 23, 59, 59, nanosecond: 999_999_999)
    3.upto(9) do |i|
      Time.utc(2014, 11, i).at_end_of_week.should eq Time.utc(2014, 11, 9, 23, 59, 59, nanosecond: 999_999_999)
    end

    t1.at_end_of_day.should eq Time.utc(2014, 11, 25, 23, 59, 59, nanosecond: 999_999_999)
    t1.at_end_of_hour.should eq Time.utc(2014, 11, 25, 10, 59, 59, nanosecond: 999_999_999)
    t1.at_end_of_minute.should eq Time.utc(2014, 11, 25, 10, 11, 59, nanosecond: 999_999_999)
    t1.at_end_of_second.should eq Time.utc(2014, 11, 25, 10, 11, 12, nanosecond: 999_999_999)

    t1.at_midday.should eq Time.utc(2014, 11, 25, 12)

    t1.at_beginning_of_semester.should eq Time.utc(2014, 7, 1)
    t2.at_beginning_of_semester.should eq Time.utc(2014, 1, 1)

    t1.at_end_of_semester.should eq Time.utc(2014, 12, 31, 23, 59, 59, nanosecond: 999_999_999)
    t2.at_end_of_semester.should eq Time.utc(2014, 6, 30, 23, 59, 59, nanosecond: 999_999_999)
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

  describe "#to_local_in" do
    it "keeps wall clock" do
      location = Time::Location.fixed(3600)
      location2 = Time::Location.fixed(12345)
      time1 = Time.now(location)
      time1.location.should eq(location)

      time2 = time1.to_local_in(location2)
      time2.location.should eq(location2)
      time2.year.should eq time1.year
      time2.month.should eq time1.month
      time2.day.should eq time1.day
      time2.hour.should eq time1.hour
      time2.minute.should eq time1.minute
      time2.second.should eq time1.second
      time2.nanosecond.should eq time1.nanosecond
    end

    it "is the difference of offsets apart" do
      location = Time::Location.fixed(3600)
      location2 = Time::Location.fixed(12345)
      time1 = Time.now(location)
      time2 = time1.to_local_in(location2)

      (time2 - time1).should eq (time1.offset - time2.offset).seconds
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
      time.to_s.should eq "2017-11-25 22:06:17 +01:00"
    end
  end

  describe ".days_in_month" do
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

  it ".days_in_year" do
    Time.days_in_year(2005).should eq(365)
    Time.days_in_year(2004).should eq(366)
    Time.days_in_year(2000).should eq(366)
    Time.days_in_year(1990).should eq(365)
  end

  describe ".leap_year?" do
    it "knows that 400-year centuries are leap years" do
      {1600, 2000, 2400}.each do |year|
        Time.leap_year?(year).should be_true
      end
    end

    it "knows that 100-year centuries are normal years" do
      {1700, 1800, 1900, 2100, 2200, 2300}.each do |year|
        Time.leap_year?(year).should be_false
      end
    end

    it "knows that typical non-century leap years are divisibly by 4" do
      {1968, 1972, 2004, 2020}.each do |year|
        Time.leap_year?(year).should be_true
      end
    end

    it "knows years *not* divisible by 4 are normal" do
      {1965, 1999, 2001, 2018, 2019, 2021, 2099, 2101}.each do |year|
        Time.leap_year?(year).should be_false
      end
    end
  end

  typeof(Time.now.year)
  typeof(1.minute.from_now.year)
  typeof(1.minute.ago.year)
  typeof(1.month.from_now.year)
  typeof(1.month.ago.year)
  typeof(Time.now.to_utc)
  typeof(Time.now.to_local)
end

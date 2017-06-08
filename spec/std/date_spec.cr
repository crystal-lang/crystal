#!/usr/bin/env bin/crystal --run
require "spec"
require "date"


describe "Date" do
  it "can be created for a given year, month, day" do
    date = Date.new(2014, 1, 31)
  end

  it "can be created for a given Julian Day Number" do
    date = Date.new(2456689)
    date.jdn.should eq(2456689)
  end

  it "prints in yyyy-mm-dd format" do
    date = Date.new(2014, 1, 31)
    date.to_s.should eq("2014-01-31")
  end

  it "can get the Julian day number" do
    date = Date.new(2014, 1, 31)
    date.jdn.should eq(2456689)
  end

  it "is comparable to another Date" do
    date1 = Date.new(2014, 1, 31)
    date2 = Date.new(2014, 1, 31)
    date3 = Date.new(2014, 2, 1)
    date1.should eq(date2)
    (date1 <= date2).should be_true
    (date1 >= date2).should be_true
    (date1 < date3).should be_true
    (date1 > date3).should be_false
  end

  it "can be added to a Date::Interval" do
    date = Date.new(2014, 1, 31)
    (date + 3.days).should eq(Date.new(2014, 2, 3))
  end

  it "can subtract a Date::Interval from it" do
    date = Date.new(2014, 2, 3)
    (date - 3.days).should eq(Date.new(2014, 1, 31))
  end

  describe "using the default calendar" do
    # Run `cal 9 1752` on a UNIX system to see why we want to do this.
    # This is the transition date for Britain and its colonies; other coutries transitioned at different times.
    it "changes from Julian to Gregorian in September 1752" do
      (Date.new(1752, 9, 2) + 1.days).should eq(Date.new(1752, 9, 14))
    end
  end

  describe "using the Julian calendar" do
    it "can be created for a given year, month, day" do
      date = Date.new(2014, 1, 31, Date::Calendar::Julian)
    end

    it "can be created for a given Julian Day Number" do
      date = Date.new(2456689, Date::Calendar::Julian)
      date.jdn.should eq(2456689)
    end

    it "can be compared to another Date using a different calendar" do
      date1 = Date.new(2014, 1, 31)
      date2 = Date.new(2014, 1, 18, Date::Calendar::Julian)
      date1.should eq(date2)
    end
  end

end


describe "Date::Interval" do
  it "can be compared with another Date::Interval" do
    Date::Interval.new(3).should eq(Date::Interval.new(3))
    (Date::Interval.new(2) < Date::Interval.new(3)).should be_true
    (Date::Interval.new(3) > Date::Interval.new(2)).should be_true
  end

  it "can be gotten from Int#days" do
    3.days.should eq(Date::Interval.new(3))
  end

  it "can be added to another Date::Interval" do
    (3.days + 4.days).should eq(Date::Interval.new(7))
  end

  it "can be subtracted from another Date::Interval" do
    (7.days - 4.days).should eq(Date::Interval.new(3))
  end
end

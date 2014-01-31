#!/usr/bin/env bin/crystal --run
require "spec"
require "date"

describe "Date" do
  it "initializes from year, month, day" do
    date = Date.new(2014, 1, 31)
  end

  it "prints in yyyy-mm-dd format" do
    date = Date.new(2014, 1, 31)
    date.to_s.should eq("2014-01-31")
  end

  it "can get the Julian day number" do
    date = Date.new(2014, 1, 31)
    date.jdn.should eq(2456689)
  end
end


describe "Date::Interval" do
  it "initializes from an Int" do
    Date::Interval.new(3)
  end

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

end

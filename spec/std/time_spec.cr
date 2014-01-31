#!/usr/bin/env bin/crystal --run
require "spec"

describe "Time" do
  it "initializes from scratch" do
    time = Time.new
    (time.to_i > 1391172409).should be_true
  end

  it "initializes from year, month, ..." do
    time = Time.new(2007, 11, 1, 15, 25, 1)
    time.utc.strftime("%F %T").should eq("2007-11-01 14:25:01")
  end

  it "initializes from float" do
    seconds = 1377950511.728946
    time = Time.at(seconds)
    time.to_f.should eq(seconds)
  end

  it "initializes from timespec" do
    seconds = 1391083328

    timespec :: C::TimeSpec
    timespec.tv_sec  = seconds.to_timet
    timespec.tv_nsec = 0.to_timet

    time = Time.new(timespec)
    time.to_i.should eq(seconds)
  end

  it "substracts seconds from time" do
    time = Time.at(1234)
    time2 = time - 234
    time2.to_f.should eq(1000)
  end

  it "substracts two times" do
    (Time.at(1234) - Time.at(234)).should eq(1000)
  end

  it "checks utc is not set by default" do
    time = Time.new
    time.utc?.should be_false
  end

  it "converts from local time to utc" do
    time = Time.at(1391172409)
    time.to_i.should eq(1391172409)
    time.utc.to_s.should eq("2014-01-31 12:46:49 UTC")
    time.to_i.should eq(1391172409)
  end
end

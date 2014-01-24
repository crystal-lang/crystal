#!/usr/bin/env bin/crystal --run
require "spec"

describe "Time" do
  it "initializes from float" do
    seconds = 1377950511.728946
    time = Time.new(seconds)
    time.to_f.should eq(seconds)
  end

  # it "initializes from year, month, ..." do
  #   time = Time.at(2007, 11, 1, 15, 25, 1)
  #   puts time.to_f
  # end

  it "substracts seconds from time" do
    time = Time.new(1234)
    time2 = time - 234
    time2.to_f.should eq(1000)
  end

  it "substracts two times" do
    (Time.new(1234) - Time.new(234)).should eq(1000)
  end
end

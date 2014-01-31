#!/usr/bin/env bin/crystal --run
require "spec"
require "date"

describe "Date" do
  it "initializes from year, month, day" do
    date = Date.new(2014, 1, 31)
  end
end

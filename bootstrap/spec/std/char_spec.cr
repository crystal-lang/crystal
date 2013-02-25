#!/usr/bin/env bin/crystal -run
require "spec"

describe "Char" do
  describe "upcase" do
    assert { 'a'.upcase.should eq('A') }
    assert { '1'.upcase.should eq('1') }
  end

  describe "downcase" do
    assert { 'A'.downcase.should eq('a') }
    assert { '1'.downcase.should eq('1') }
  end

  describe "whitespace?" do
    [' ', '\t', '\n', '\v', '\f', '\r'].each do |char|
      assert { char.whitespace?.should be_true }
    end
  end
end

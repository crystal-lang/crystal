#!/usr/bin/env bin/crystal --run
require "spec"

describe "Spec matchers" do

  describe "should be_ok" do
    it "passes for true value" do
      true.should be_ok
    end
    it "passes for a simple, truthy value" do
      42.should be_ok
    end
  end

  describe "should_not be_ok" do
    it "passes for false" do
      false.should_not be_ok
    end
    it "passes for nil" do
      nil.should_not be_ok
    end
  end

end

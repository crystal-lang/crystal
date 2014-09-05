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

describe "BeOkExpectation" do

  describe "match" do
    it "returns the value passed in" do
      Spec::BeOkExpectation.new.match(42).should eq(42)
    end
  end

  describe "failure_message" do
    it "describes the reason for failure" do
      exp = Spec::BeOkExpectation.new
      exp.match("42")
      exp.failure_message.should eq("expected: \"42\" to be ok")
    end
  end

  describe "negative_failure_message" do
    it "describes the reason for failure" do
      exp = Spec::BeOkExpectation.new
      exp.match("42")
      exp.negative_failure_message.should eq("expected: \"42\" not to be ok")
    end
  end

end

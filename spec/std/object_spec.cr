require "spec"

class StringWrapper
  delegate downcase, @string
  delegate upcase, capitalize, @string

  def initialize(@string)
  end
end

describe "Object" do
  describe "delegate" do
    wrapper = StringWrapper.new("HellO")
    wrapper.downcase.should eq("hello")
    wrapper.upcase.should eq("HELLO")
    wrapper.capitalize.should eq("Hello")
  end
end

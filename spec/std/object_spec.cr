require "spec"

class StringWrapper
  delegate downcase, @string
  delegate upcase, capitalize, @string

  def initialize(@string)
  end
end

class AliasMethodExample
  def long_method_name
    42
  end

  alias_method short_name, long_method_name
end

describe "Object" do
  describe "delegate" do
    wrapper = StringWrapper.new("HellO")
    wrapper.downcase.should eq("hello")
    wrapper.upcase.should eq("HELLO")
    wrapper.capitalize.should eq("Hello")
  end

  describe "alias_method" do
    ex = AliasMethodExample.new
    ex.long_method_name.should eq(42)
    ex.short_name.should eq(42)
  end
end

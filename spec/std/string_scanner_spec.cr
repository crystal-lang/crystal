require "spec"
require "string_scanner"

describe StringScanner, "#scan" do
  it "returns the string matched and advances the offset" do
    s = StringScanner.new("this is a string")
    s.scan(/\w+\s/).should eq("this ")
    s.scan(/\w+\s/).should eq("is ")
    s.scan(/\w+\s/).should eq("a ")
    s.scan(/\w+/).should eq("string")
  end

  it "returns nil if it can't match from the offset" do
    s = StringScanner.new("test string")
    s.scan(/\w+/  ).should_not be_nil # => "test"
    s.scan(/\w+/  ).should     be_nil
    s.scan(/\s\w+/).should_not be_nil # => " string"
    s.scan(/.*/   ).should     be_nil
  end
end

describe StringScanner, "#eos" do
  it "it is true when the offset is at the end" do
    s = StringScanner.new("this is a string")
    s.eos?.should eq(false)
    s.scan(/(\w+\s?){4}/)
    s.eos?.should eq(true)
  end
end

describe StringScanner, "#rest" do
  it "returns the remainder of the string from the offset" do
    s = StringScanner.new("this is a string")
    s.rest.should eq("this is a string")

    s.scan(/this is a /)
    s.rest.should eq("string")

    s.scan(/string/)
    s.rest.should eq("")
  end
end

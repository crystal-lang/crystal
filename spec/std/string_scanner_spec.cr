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
    s.scan(/\w+/).should_not be_nil # => "test"
    s.scan(/\w+/).should be_nil
    s.scan(/\s\w+/).should_not be_nil # => " string"
    s.scan(/.*/).should_not be_nil    # => ""
  end
end

describe StringScanner, "#scan_until" do
  it "returns the string matched and advances the offset" do
    s = StringScanner.new("test string")
    s.scan_until(/tr/).should eq("test str")
    s.offset.should eq(8)
    s.scan_until(/g/).should eq("ing")
  end

  it "returns nil if it can't match from the offset" do
    s = StringScanner.new("test string")
    s.offset = 8
    s.scan_until(/tr/).should be_nil
  end
end

describe StringScanner, "#skip" do
  it "advances the offset but does not returns the string matched" do
    s = StringScanner.new("this is a string")

    s.skip(/\w+\s/).should eq(5)
    s.offset.should eq(5)
    s[0]?.should_not be_nil

    s.skip(/\d+/).should eq(nil)
    s.offset.should eq(5)

    s.skip(/\w+\s/).should eq(3)
    s.offset.should eq(8)

    s.skip(/\w+\s/).should eq(2)
    s.offset.should eq(10)

    s.skip(/\w+/).should eq(6)
    s.offset.should eq(16)
  end
end

describe StringScanner, "#skip_until" do
  it "advances the offset but does not returns the string matched" do
    s = StringScanner.new("this is a string")

    s.skip_until(/not/).should eq(nil)
    s.offset.should eq(0)
    s[0]?.should be_nil

    s.skip_until(/a\s/).should eq(10)
    s.offset.should eq(10)
    s[0]?.should_not be_nil

    s.skip_until(/ng/).should eq(6)
    s.offset.should eq(16)
  end
end

describe StringScanner, "#eos" do
  it "it is true when the offset is at the end" do
    s = StringScanner.new("this is a string")
    s.eos?.should eq(false)
    s.skip(/(\w+\s?){4}/)
    s.eos?.should eq(true)
  end
end

describe StringScanner, "#check" do
  it "returns the string matched but does not advances the offset" do
    s = StringScanner.new("this is a string")
    s.offset = 5

    s.check(/\w+\s/).should eq("is ")
    s.offset.should eq(5)
    s.check(/\w+\s/).should eq("is ")
    s.offset.should eq(5)
  end

  it "returns nil if it can't match from the offset" do
    s = StringScanner.new("test string")
    s.check(/\d+/).should be_nil
  end
end

describe StringScanner, "#check_until" do
  it "returns the string matched and advances the offset" do
    s = StringScanner.new("test string")
    s.check_until(/tr/).should eq("test str")
    s.offset.should eq(0)
    s.check_until(/g/).should eq("test string")
    s.offset.should eq(0)
  end

  it "returns nil if it can't match from the offset" do
    s = StringScanner.new("test string")
    s.offset = 8
    s.check_until(/tr/).should be_nil
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

describe StringScanner, "#[]" do
  it "allows access to subgroups of the last match" do
    s = StringScanner.new("Fri Dec 12 1975 14:39")
    regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
    s.scan(regex).should eq("Fri Dec 12")
    s[0].should eq("Fri Dec 12")
    s[1].should eq("Fri")
    s[2].should eq("Dec")
    s[3].should eq("12")
    s["wday"].should eq("Fri")
    s["month"].should eq("Dec")
    s["day"].should eq("12")
  end

  it "raises when there is no last match" do
    s = StringScanner.new("Fri Dec 12 1975 14:39")
    s.scan(/this is not there/)

    expect_raises { s[0] }
  end

  it "raises when there is no subgroup" do
    s = StringScanner.new("Fri Dec 12 1975 14:39")
    regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
    s.scan(regex)

    s[0].should_not be_nil
    expect_raises { s[5] }
    expect_raises { s["something"] }
  end
end

describe StringScanner, "#[]?" do
  it "allows access to subgroups of the last match" do
    s = StringScanner.new("Fri Dec 12 1975 14:39")
    result = s.scan(/(?<wday>\w+) (?<month>\w+) (?<day>\d+)/)

    result.should eq("Fri Dec 12")
    s[0]?.should eq("Fri Dec 12")
    s[1]?.should eq("Fri")
    s[2]?.should eq("Dec")
    s[3]?.should eq("12")
    s["wday"]?.should eq("Fri")
    s["month"]?.should eq("Dec")
    s["day"]?.should eq("12")
  end

  it "returns nil when there is no last match" do
    s = StringScanner.new("Fri Dec 12 1975 14:39")
    s.scan(/this is not there/)

    s[0]?.should be_nil
  end

  it "raises when there is no subgroup" do
    s = StringScanner.new("Fri Dec 12 1975 14:39")
    s.scan(/(?<wday>\w+) (?<month>\w+) (?<day>\d+)/)

    s[0].should_not be_nil
    s[5]?.should be_nil
    s["something"]?.should be_nil
  end
end

describe StringScanner, "#string" do
  assert { StringScanner.new("foo").string.should eq("foo") }
end

describe StringScanner, "#offset" do
  it "returns the current position" do
    s = StringScanner.new("this is a string")
    s.offset.should eq(0)
    s.scan(/\w+/)
    s.offset.should eq(4)
  end
end

describe StringScanner, "#offset=" do
  it "sets the current position" do
    s = StringScanner.new("this is a string")
    s.offset = 5
    s.scan(/\w+/).should eq("is")
  end

  it "raises on negative positions" do
    s = StringScanner.new("this is a string")
    expect_raises(IndexError) { s.offset = -2 }
  end
end

describe StringScanner, "#inspect" do
  it "has information on the scanner" do
    s = StringScanner.new("this is a string")
    s.inspect.should eq(%(#<StringScanner 0/16 "this " >))
    s.scan(/\w+\s/)
    s.inspect.should eq(%(#<StringScanner 5/16 "s is " >))
    s.scan(/\w+\s/)
    s.inspect.should eq(%(#<StringScanner 8/16 "s a s" >))
    s.scan(/\w+\s\w+/)
    s.inspect.should eq(%(#<StringScanner 16/16 "tring" >))
  end
end

describe StringScanner, "#peek" do
  it "shows the next len characters without advancing the offset" do
    s = StringScanner.new("this is a string")
    s.offset.should eq(0)
    s.peek(4).should eq("this")
    s.offset.should eq(0)
    s.peek(7).should eq("this is")
    s.offset.should eq(0)
  end
end

describe StringScanner, "#reset" do
  it "resets the scan offset to the beginning and clears the last match" do
    s = StringScanner.new("this is a string")
    s.scan_until(/str/)
    s[0]?.should_not be_nil
    s.offset.should_not eq(0)

    s.reset
    s[0]?.should be_nil
    s.offset.should eq(0)
  end
end

describe StringScanner, "#terminate" do
  it "moves the scan offset to the end of the string and clears the last match" do
    s = StringScanner.new("this is a string")
    s.scan_until(/str/)
    s[0]?.should_not be_nil
    s.eos?.should eq(false)

    s.terminate
    s[0]?.should be_nil
    s.eos?.should eq(true)
  end
end

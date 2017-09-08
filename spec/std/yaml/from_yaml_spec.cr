require "spec"
require "yaml"

private struct ObjectStub
  getter called : Bool

  def self.new(pull : YAML::PullParser)
    pull.read_scalar
    new(true)
  end

  def initialize(@called)
  end
end

describe "Object.from_yaml" do
  it "should create call .new on with a YAML::PullParser" do
    ObjectStub.from_yaml("hello").called.should be_true
  end
end

describe "Nil.from_yaml" do
  it "should serialize and deserialize" do
    Nil.from_yaml(nil.to_yaml).should eq nil
  end

  values = YAML::NULL_VALUES

  it "should return nil if a YAML null value" do
    values.each do |value|
      # Test with an array since a standalone empty value shows as STREAM_END
      Array(Nil).from_yaml("- " + value).should eq [nil]
    end
  end

  it "should raise if a YAML null value is quoted" do
    values.each do |value|
      expect_raises(YAML::ParseException) do
        Nil.from_yaml %("#{value}")
      end
      expect_raises(YAML::ParseException) do
        Nil.from_yaml "'#{value}'"
      end
    end
  end

  it "should raise if not a null value" do
    expect_raises(YAML::ParseException) do
      Nil.from_yaml "hello"
    end
  end
end

describe "Bool.from_yaml" do
  describe "true values" do
    it "should serialize and deserialize" do
      Bool.from_yaml(true.to_yaml).should eq true
    end

    values = YAML::TRUE_VALUES

    it "should return true if a truthy value" do
      values.each do |value|
        Bool.from_yaml(value).should eq true
      end
    end

    it "should raise if a truthy value is quoted" do
      values.each do |value|
        expect_raises(YAML::ParseException) do
          Bool.from_yaml %("#{value}")
        end
        expect_raises(YAML::ParseException) do
          Bool.from_yaml %('#{value}')
        end
      end
    end
  end

  describe "false values" do
    it "should serialize and deserialize" do
      Bool.from_yaml(false.to_yaml).should eq false
    end

    values = YAML::FALSE_VALUES

    it "should return true if a falsey value" do
      values.each do |value|
        Bool.from_yaml(value).should eq false
      end
    end

    it "should raise if a falsey value is quoted" do
      values.each do |value|
        expect_raises(YAML::ParseException) do
          Bool.from_yaml %("#{value}")
        end
      end
      values.each do |value|
        expect_raises(YAML::ParseException) do
          Bool.from_yaml %('#{value}')
        end
      end
    end
  end

  it "should raise if not a bool value" do
    expect_raises(YAML::ParseException) do
      Bool.from_yaml "hello"
    end
  end
end

[Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64].each do |type|
  describe "#{type.name}.from_yaml" do
    it "should serialize and deserialize" do
      type.from_yaml(type.new("1").to_yaml).should eq type.new("1")
    end

    it "should parse possible values" do
      values = {"1", "-1", "0x_0A_74_AE", "0b1010_0111_0100_1010_1110", "02472256"}
      values.each do |value|
        type.from_yaml(value).class.should eq type
      end
    end

    it "should parse a number into an #{type.name}" do
      type.from_yaml("1").should eq type.new("1")
    end

    it "should raise if an int is quoted" do
      expect_raises(YAML::ParseException) do
        type.from_yaml %("1")
      end
      expect_raises(YAML::ParseException) do
        type.from_yaml %('1')
      end
    end
  end
end

[Float32, Float64].each do |type|
  describe "#{type.name}.from_yaml" do
    it "should serialize and deserialize" do
      type.from_yaml(type.new("1.0").to_yaml).should eq type.new("1.0")
    end

    it "should parse possible values" do
      values = {
        ".inf", ".Inf", ".INF", "+.inf", "+.Inf", "+.INF",
        "-.inf", "-.Inf", "-.INF",
        ".nan", ".NaN", ".NAN",
        "+1", "1", "-1",
        "1.1", "+1.1", "-1.1",
      }
      values.each do |value|
        type.from_yaml(value).class.should eq type
      end
    end

    it "should parse a number into an #{type.name}" do
      type.from_yaml("1").should eq type.new("1")
    end

    it "should parse a float into an #{type.name}" do
      type.from_yaml("1.1").should eq type.new("1.1")
    end

    it "should raise if a float value is quoted" do
      expect_raises(YAML::ParseException) do
        type.from_yaml %("1.1")
      end
      expect_raises(YAML::ParseException) do
        type.from_yaml %('1.1')
      end
    end
  end
end

describe "String.from_yaml" do
  it "should serialize and deserialize" do
    String.from_yaml("hi".to_yaml).should eq "hi"
  end

  it "should parse a string" do
    String.from_yaml("hello").should eq "hello"
  end

  it "should parse a quoted string" do
    String.from_yaml(%("hello")).should eq "hello"
    String.from_yaml(%('hello')).should eq "hello"
  end

  it "should parse a literal string" do
    String.from_yaml("|\n  hello").should eq "hello"
  end

  it "should parse a folded string" do
    String.from_yaml(">\n  hello").should eq "hello"
  end

  context "reserved values" do
    values = {
      "true", "True", "TRUE", "on", "On", "ON", "y", "Y", "yes", "Yes", "YES",
      "false", "False", "FALSE", "off", "Off", "OFF", "n", "N", "no", "No", "NO",
      "", "NULL", "Null", "null", "~",
      ".inf", ".Inf", ".INF", "+.inf", "+.Inf", "+.INF",
      "-.inf", "-.Inf", "-.INF",
      ".nan", ".NaN", ".NAN",
      "+1", "1", "-1",
      "1.1", "+1.1", "-1.1",
      "0x_0A_74_AE", "0b1010_0111_0100_1010_1110", "02472256",
      "2001-12-15T02:59:43.1Z",
    }

    it "should raise if a reserved value" do
      values.each do |value|
        expect_raises(YAML::ParseException) do
          String.from_yaml(value)
        end
      end
    end

    it "should parse if a reserved value is quoted" do
      values.each do |value|
        String.from_yaml(%("#{value}")).should eq value
      end
      values.each do |value|
        String.from_yaml(%('#{value}')).should eq value
      end
    end
  end
end

describe "Array.from_yaml" do
  it "should serialize and deserialize" do
    Array(String).from_yaml(["hi"].to_yaml).should eq ["hi"]
  end

  it "it should parse an array of the correct objects" do
    result = Array(String).from_yaml <<-YAML
      - one
      - two
      - three
    YAML
    result.should eq ["one", "two", "three"]
  end

  context "with a union type" do
    it "it should parse an array of the correct objects" do
      result = Array(String | Int32 | Float64).from_yaml <<-YAML
        - one
        - 1
        - 1.0
      YAML
      result.should eq ["one", 1, 1.0]
    end
  end
end

describe "Hash.from_yaml" do
  it "should serialize and deserialize" do
    Hash(String, String).from_yaml({"hello" => "world"}.to_yaml).should eq ({"hello" => "world"})
  end

  it "it should parse an array of the correct objects" do
    result = Hash(String, String).from_yaml <<-YAML
      foo: one
      bar: two
      baz: three
    YAML
    result.should eq ({"foo" => "one", "bar" => "two", "baz" => "three"})
  end

  context "with a union type" do
    it "it should parse an array of the correct objects" do
      result = Hash(String, String | Int32 | Float64).from_yaml <<-YAML
        foo: 1
        bar: two
        baz: 3.0
      YAML
      result.should eq ({"foo" => 1, "bar" => "two", "baz" => 3.0})
    end
  end
end

describe "Tuple.from_yaml" do
  it "should serialize and deserialize" do
    Tuple(String, String).from_yaml({"hello", "world"}.to_yaml).should eq ({"hello", "world"})
  end

  it "it should parse an array of the correct objects" do
    result = Tuple(String, String, String).from_yaml "- one\n- two\n- three"
    result.should eq ({"one", "two", "three"})
  end

  context "with a union type" do
    it "it should parse an array of the correct objects" do
      result = Tuple(String | Int32 | Float64, String | Int32 | Float64, String | Int32 | Float64).from_yaml "- one\n- 1\n- 1.0"
      result.should eq ({"one", 1, 1.0})
    end
  end
end

describe "NamedTuple.from_yaml" do
  it "it should parse an array of the correct objects" do
    result = NamedTuple(foo: String, bar: String, baz: String).from_yaml "foo: one\nbar: two\nbaz: three"
    result.should eq ({foo: "one", bar: "two", baz: "three"})
  end
end

enum TestEnum
  Red
  Green
  Blue
end

describe "Enum.from_yaml" do
  it "should serialize and deserialize" do
    TestEnum.from_yaml(TestEnum::Red.to_yaml).should eq TestEnum::Red
  end

  it "should parse from string" do
    TestEnum.from_yaml("red").should eq TestEnum::Red
  end

  it "should parse from int" do
    TestEnum.from_yaml("1").should eq TestEnum::Green
  end
end

describe "Union.from_yaml" do
  it "should compile into any of the types" do
    (Bool | Int32).from_yaml("true").should eq true
    (Bool | Int32).from_yaml("1").should eq 1
  end

  it "should raise if not a unions type" do
    expect_raises(YAML::ParseException) do
      (Bool | Int32).from_yaml("foo")
    end
  end
end

describe "Time.from_yaml" do
  it "should parse time" do
    time = Time.now
    time_string = Time::Format::ISO_8601_DATE_TIME.format(time)
    Time.from_yaml(time_string).epoch.should eq time.epoch
  end

  it "should not parse an invalid time string" do
    expect_raises(YAML::ParseException) do
      Time.from_yaml("not a time")
    end
  end
end

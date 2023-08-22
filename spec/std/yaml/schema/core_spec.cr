require "spec"
require "yaml"

private def it_parses(string, expected, file = __FILE__, line = __LINE__)
  it "parses #{string.inspect}", file, line do
    YAML::Schema::Core.parse(string).should eq(expected)
  end
end

private def it_raises_on_parse(string, message, file = __FILE__, line = __LINE__)
  it "raises on parse #{string.inspect}", file, line do
    expect_raises(YAML::ParseException, message) do
      YAML::Schema::Core.parse(string)
    end
  end
end

private def it_parses_scalar(string, expected, file = __FILE__, line = __LINE__)
  it "parses #{string.inspect}", file, line do
    YAML::Schema::Core.parse_scalar(string).should eq(expected)
  end
end

private def it_parses_string(string, file = __FILE__, line = __LINE__)
  it_parses_scalar(string, string, file, line)
end

private def it_parses_scalar_from_pull(string, expected, file = __FILE__, line = __LINE__)
  it_parses_scalar_from_pull(string, file, line) do |value|
    value.should eq(expected)
  end
end

private def it_parses_scalar_from_pull(string, file = __FILE__, line = __LINE__, &block : YAML::Any::Type ->)
  it "parses #{string.inspect}", file, line do
    pull = YAML::PullParser.new(%(value: #{string}))
    pull.read_stream_start
    pull.read_document_start
    pull.read_mapping_start
    pull.read_scalar # key

    block.call(YAML::Schema::Core.parse_scalar(pull).as(YAML::Any::Type))
  end
end

private def parse_first_node(content)
  parser = YAML::Nodes::Parser.new(%(value: #{content}))
  parser.parse.nodes.first.as(YAML::Nodes::Mapping).nodes[1]
end

describe YAML::Schema::Core do
  # nil
  it_parses_scalar "~", nil
  it_parses_scalar "null", nil
  it_parses_scalar "Null", nil
  it_parses_scalar "NULL", nil

  # true
  it_parses_scalar "yes", true
  it_parses_scalar "Yes", true
  it_parses_scalar "YES", true
  it_parses_scalar "true", true
  it_parses_scalar "True", true
  it_parses_scalar "TRUE", true
  it_parses_scalar "on", true
  it_parses_scalar "On", true
  it_parses_scalar "ON", true

  # false
  it_parses_scalar "no", false
  it_parses_scalar "No", false
  it_parses_scalar "NO", false
  it_parses_scalar "false", false
  it_parses_scalar "False", false
  it_parses_scalar "FALSE", false
  it_parses_scalar "off", false
  it_parses_scalar "Off", false
  it_parses_scalar "OFF", false

  # +infinity
  it_parses_scalar ".inf", Float64::INFINITY
  it_parses_scalar ".Inf", Float64::INFINITY
  it_parses_scalar ".INF", Float64::INFINITY
  it_parses_scalar "+.inf", Float64::INFINITY
  it_parses_scalar "+.Inf", Float64::INFINITY
  it_parses_scalar "+.INF", Float64::INFINITY

  # -infinity
  it_parses_scalar "-.inf", -Float64::INFINITY
  it_parses_scalar "-.Inf", -Float64::INFINITY
  it_parses_scalar "-.INF", -Float64::INFINITY

  # nan
  it "parses nan" do
    {".nan", ".NaN", ".NAN"}.each do |string|
      value = YAML::Schema::Core.parse_scalar(string)
      value.as(Float64).nan?.should be_true
    end
  end

  # integer (base 10)
  it_parses_scalar "0", 0
  it_parses_scalar "123", 123
  it_parses_scalar "+123", 123
  it_parses_scalar "-123", -123

  # integer (binary)
  it_parses_scalar "0b0", 0
  it_parses_scalar "0b10110", 0b10110

  # integer (octal)
  it_parses_scalar "00", 0
  it_parses_scalar "0o0", 0
  it_parses_scalar "0o123", 0o123
  it_parses_scalar "0755", 0o755

  # integer (hex)
  it_parses_scalar "0x0", 0
  it_parses_scalar "0x123abc", 0x123abc
  it_parses_scalar "-0x123abc", -0x123abc

  # float
  it_parses_scalar "1.2", 1.2
  it_parses_scalar "0.815", 0.815
  it_parses_scalar "0.", 0.0
  it_parses_scalar "-0.0", 0.0
  it_parses_scalar "1_234.2", 1_234.2
  it_parses_scalar "-2E+05", -2e05
  it_parses_scalar "+12.3", 12.3
  it_parses_scalar ".5", 0.5
  it_parses_scalar "+.5", 0.5
  it_parses_scalar "-.5", -0.5

  # time
  it_parses_scalar "2002-12-14", Time.utc(2002, 12, 14)
  it_parses_scalar "2002-1-2", Time.utc(2002, 1, 2)
  it_parses_scalar "2002-1-2T10:11:12", Time.utc(2002, 1, 2, 10, 11, 12)
  it_parses_scalar "2002-1-2   10:11:12", Time.utc(2002, 1, 2, 10, 11, 12)
  it_parses_scalar "2002-1-2   1:11:12", Time.utc(2002, 1, 2, 1, 11, 12)
  it_parses_scalar "2002-1-2T10:11:12.3", Time.utc(2002, 1, 2, 10, 11, 12, nanosecond: 300_000_000)
  it_parses_scalar "2002-1-2T10:11:12.34", Time.utc(2002, 1, 2, 10, 11, 12, nanosecond: 340_000_000)
  it_parses_scalar "2002-1-2T10:11:12.345", Time.utc(2002, 1, 2, 10, 11, 12, nanosecond: 345_000_000)
  it_parses_scalar "2002-1-2T10:11:12.3456", Time.utc(2002, 1, 2, 10, 11, 12, nanosecond: 345_600_000)
  it_parses_scalar "2002-1-2T10:11:12Z", Time.utc(2002, 1, 2, 10, 11, 12)
  it_parses_scalar "2002-1-2T10:11:12 Z", Time.utc(2002, 1, 2, 10, 11, 12)
  it_parses_scalar "2002-1-2T10:11:12 +3", Time.utc(2002, 1, 2, 7, 11, 12)
  it_parses_scalar "2002-1-2T10:11:12 +03:00", Time.utc(2002, 1, 2, 7, 11, 12)
  it_parses_scalar "2002-1-2T10:11:12 -03:00", Time.utc(2002, 1, 2, 13, 11, 12)
  it_parses_scalar "2002-1-2T10:11:12 -03:31", Time.utc(2002, 1, 2, 13, 42, 12)
  it_parses_scalar "2002-1-2T10:11:12-03:31", Time.utc(2002, 1, 2, 13, 42, 12)
  it_parses_scalar "2002-1-2T10:11:12 +0300", Time.utc(2002, 1, 2, 7, 11, 12)

  # invalid time
  it_parses_string "2002-34-45"
  it_parses_string "2002-12-14 x"
  it_parses_string "2002-1-2T10:11:12x"
  it_parses_string "2002-1-2T10:11:12Zx"
  it_parses_string "2002-1-2T10:11:12+03x"

  # non-plain style
  it_parses_scalar_from_pull %("1"), "1"

  # bools according to the spec, but parsed as strings in Python and Ruby,
  # so we do the same in Crystal for "compatibility"
  it_parses_scalar "y", "y"
  it_parses_scalar "Y", "Y"
  it_parses_scalar "n", "n"
  it_parses_scalar "N", "N"

  # !!map
  it_parses "!!map {1: 2}", {1 => 2}
  it_raises_on_parse "!!map 1", "Expected MAPPING_START"

  # !!omap
  it_parses "!!omap {1: 2}", {1 => 2}
  it_raises_on_parse "!!omap 1", "Expected MAPPING_START"

  # !!pairs
  it_parses "!!pairs [{1: 2}, {3: 4}]", [{1 => 2}, {3 => 4}]
  it_raises_on_parse "!!pairs 1", "Expected SEQUENCE_START"
  it_raises_on_parse "!!pairs [{1: 2, 3: 4}]", "Expected MAPPING_END"

  # !!set
  it_parses "!!set { 1, 2, 3 }", Set{1, 2, 3}
  it_raises_on_parse "!!set 1", "Expected MAPPING_START"

  # !!seq
  it_parses "!!seq [ 1, 2, 3 ]", [1, 2, 3]
  it_raises_on_parse "!!seq 1", "Expected SEQUENCE_START"

  # !!binary
  it_parses "!!binary aGVsbG8=", "hello".to_slice
  it_raises_on_parse "!!binary [1]", "Expected SCALAR"
  it_raises_on_parse "!!binary 1", "Error decoding Base64"

  # !!bool
  it_parses "!!bool yes", true
  it_raises_on_parse "!!bool 1", "Invalid bool"

  # !!float
  it_parses "!!float '1.2'", 1.2
  it_parses "!!float '0.5'", 0.5
  it_parses "!!float '1_234.2'", 1_234.2

  it_parses "!!float -1", -1.0
  it_parses "!!float 0", 0.0
  it_parses "!!float 2.3e4", 2.3e4

  it "parses !!float .nan" do
    YAML::Schema::Core.parse("!!float .nan").as_f.nan?.should be_true
  end

  it_parses "!!float .inf", Float64::INFINITY
  it_raises_on_parse "!!float 'hello'", "Invalid float"

  # !!int
  it_parses "!!int 0", 0
  it_parses "!!int 123", 123
  it_parses "!!int 0b10", 0b10
  it_parses "!!int 0o123", 0o123
  it_parses "!!int 0755", 0o755
  it_parses "!!int 0xabc", 0xabc
  it_parses "!!int -123", -123
  it_raises_on_parse "!!int 'hello'", "Invalid int"

  # !!null
  it_parses "!!null ~", nil
  it_raises_on_parse "!!null 1", "Invalid null"

  # !!str
  it_parses "!!str 1", "1"
  it_raises_on_parse "!!str [1]", "Expected SCALAR"

  # # !!timestamp
  it_parses "!!timestamp 2010-01-02", Time.utc(2010, 1, 2)
  it_raises_on_parse "!!timestamp foo", "Invalid timestamp"

  it ".parse_null_or" do
    YAML::Schema::Core.parse_null_or(parse_first_node(%())) { true }.should be_nil
    YAML::Schema::Core.parse_null_or(parse_first_node(%(~))) { true }.should be_nil
    YAML::Schema::Core.parse_null_or(parse_first_node(%(""))) { true }.should be_true
    YAML::Schema::Core.parse_null_or(parse_first_node(%(''))) { true }.should be_true
  end
end

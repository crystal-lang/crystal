require "spec"
require "json"

private def it_parses(string, expected_value, file = __FILE__, line = __LINE__)
  it "parses #{string}", file, line do
    JSON.parse(string).should eq(expected_value)
  end
end

private def it_raises_on_parse(string, file = __FILE__, line = __LINE__)
  it "raises on parse #{string}", file, line do
    expect_raises JSON::ParseException do
      JSON.parse(string)
    end
  end
end

describe "JSON::Parser" do
  it_parses "1", 1
  it_parses "2.5", 2.5
  it_parses %("hello"), "hello"
  it_parses "true", true
  it_parses "false", false
  it_parses "null", nil

  it_parses "[]", [] of Int32
  it_parses "[1]", [1]
  it_parses "[1, 2, 3]", [1, 2, 3]
  it_parses "[1.5]", [1.5]
  it_parses "[null]", [nil]
  it_parses "[true]", [true]
  it_parses "[false]", [false]
  it_parses %(["hello"]), ["hello"]
  it_parses "[0]", [0]
  it_parses " [ 0 ] ", [0]

  it_parses "{}", {} of String => JSON::Type
  it_parses %({"foo": 1}), {"foo" => 1}
  it_parses %({"foo": 1, "bar": 1.5}), {"foo" => 1, "bar" => 1.5}
  it_parses %({"fo\\no": 1}), {"fo\no" => 1}

  it_parses "[[1]]", [[1]]
  it_parses %([{"foo": 1}]), [{"foo" => 1}]

  it_parses "[\"日\"]", ["日"]

  it_raises_on_parse "[1,]"
  it_raises_on_parse %({"foo": 1,})
  it_raises_on_parse "{1}"
  it_raises_on_parse %({"foo"1})
  it_raises_on_parse %("{"foo":})
  it_raises_on_parse "[0]1"
  it_raises_on_parse "[0] 1 "
  it_raises_on_parse "[\"\\u123z\"]"
end

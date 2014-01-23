require "spec"
require "json"

def it_lexes_json(string, expected_type)
  it "lexes #{string}" do
    lexer = Json::Lexer.new string
    token = lexer.next_token
    token.type.should eq(expected_type)
  end
end

def it_lexes_json_string(string, string_value)
  it "lexes #{string}" do
    lexer = Json::Lexer.new string
    token = lexer.next_token
    token.type.should eq(:STRING)
    token.string_value.should eq(string_value)
  end
end

def it_lexes_json_int(string, int_value)
  it "lexes #{string}" do
    lexer = Json::Lexer.new string
    token = lexer.next_token
    token.type.should eq(:INT)
    token.int_value.should eq(int_value)
  end
end

def it_lexes_json_float(string, float_value)
  it "lexes #{string}" do
    lexer = Json::Lexer.new string
    token = lexer.next_token
    token.type.should eq(:FLOAT)
    token.float_value.should eq(float_value)
  end
end

def it_parses_json(string, expected_value)
  it "parses #{string}" do
    Json.parse(string).should eq(expected_value)
  end
end

def it_raises_on_parse_json(string)
  it "raises on parse #{string}" do
    begin
      Json.parse(string)
      fail "expected Json.parse to raise"
    rescue Json::ParseException
    end
  end
end

describe "Json" do
  describe "Lexer" do
    it_lexes_json "", :EOF
    it_lexes_json "{", :"{"
    it_lexes_json "}", :"}"
    it_lexes_json "[", :"["
    it_lexes_json "]", :"]"
    it_lexes_json ",", :","
    it_lexes_json ":", :":"
    it_lexes_json " \n\t\r\v :", :":"
    it_lexes_json "true", :true
    it_lexes_json "false", :false
    it_lexes_json "null", :null
    it_lexes_json_string "\"hello\"", "hello"
    it_lexes_json_string "\"hello\\\"world\"", "hello\"world"
    it_lexes_json_string "\"hello\\\\world\"", "hello\\world"
    it_lexes_json_string "\"hello\\/world\"", "hello/world"
    it_lexes_json_string "\"hello\\bworld\"", "hello\bworld"
    it_lexes_json_string "\"hello\\fworld\"", "hello\fworld"
    it_lexes_json_string "\"hello\\nworld\"", "hello\nworld"
    it_lexes_json_string "\"hello\\rworld\"", "hello\rworld"
    it_lexes_json_string "\"hello\\tworld\"", "hello\tworld"
    it_lexes_json_string "\"\\u201chello world\\u201d\"", "“hello world”"
    it_lexes_json_string "\"\\uD834\\uDD1E\"", "𝄞"
    it_lexes_json_int "0", 0
    it_lexes_json_int "1", 1
    it_lexes_json_int "1234", 1234
    it_lexes_json_float "0.123", 0.123
    it_lexes_json_float "1234.567", 1234.567
    it_lexes_json_float "0e1", 0
    it_lexes_json_float "0.1e1", 0.1e1
    it_lexes_json_float "0e+12", 0
    it_lexes_json_float "0e-12", 0
    it_lexes_json_float "1e2", 1e2
    it_lexes_json_float "1e+12", 1e12
    it_lexes_json_float "1.2e-3", 1.2e-3
    it_lexes_json_int "-1", -1
    it_lexes_json_float "-1.23", -1.23
    it_lexes_json_float "-1.23e4", -1.23e4

    it_parses_json "[]", [] of Int32
    it_parses_json "[1]", [1]
    it_parses_json "[1, 2, 3]", [1, 2, 3]
    it_parses_json "[1.5]", [1.5]
    it_parses_json "[null]", [nil]
    it_parses_json "[true]", [true]
    it_parses_json "[false]", [false]
    it_parses_json %(["hello"]), ["hello"]
    it_parses_json "[0]", [0]
    it_parses_json " [ 0 ] ", [0]

    it_parses_json "{}", {} of String => Json::Type
    it_parses_json %({"foo": 1}), {"foo" => 1}
    it_parses_json %({"foo": 1, "bar": 1.5}), {"foo" => 1, "bar" => 1.5}

    it_parses_json "[[1]]", [[1]]
    it_parses_json %([{"foo": 1}]), [{"foo" => 1}]

    it_raises_on_parse_json "[1,]"
    it_raises_on_parse_json %({"foo": 1,})
    it_raises_on_parse_json "{1}"
    it_raises_on_parse_json %({"foo"1})
    it_raises_on_parse_json %("{"foo":})
    it_raises_on_parse_json "[0]1"
    it_raises_on_parse_json "[0] 1 "
    it_raises_on_parse_json "[\"\\u123z\"]"
  end
end

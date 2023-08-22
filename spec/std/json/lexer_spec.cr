require "spec"
require "json"

private def it_lexes(string, expected_kind : JSON::Token::Kind, expected_to_s = string, file = __FILE__, line = __LINE__)
  it "lexes #{string} from string", file, line do
    lexer = JSON::Lexer.new string
    token = lexer.next_token
    token.kind.should eq(expected_kind)
    token.to_s.should eq(expected_to_s)
  end

  it "lexes #{string} from IO", file, line do
    lexer = JSON::Lexer.new IO::Memory.new(string)
    token = lexer.next_token
    token.kind.should eq(expected_kind)
    token.to_s.should eq(expected_to_s)
  end
end

private def it_lexes_string(string, string_value, file = __FILE__, line = __LINE__)
  it "lexes #{string} from String", file, line do
    lexer = JSON::Lexer.new string
    token = lexer.next_token
    token.kind.should eq(JSON::Token::Kind::String)
    token.string_value.should eq(string_value)
    token.to_s.should eq(token.string_value)
  end

  it "lexes #{string} from IO", file, line do
    lexer = JSON::Lexer.new IO::Memory.new(string)
    token = lexer.next_token
    token.kind.should eq(JSON::Token::Kind::String)
    token.string_value.should eq(string_value)
    token.to_s.should eq(token.string_value)
  end
end

private def it_lexes_int(string, int_value, file = __FILE__, line = __LINE__)
  it "lexes #{string} from String", file, line do
    lexer = JSON::Lexer.new string
    token = lexer.next_token
    token.kind.should eq(JSON::Token::Kind::Int)
    token.int_value.should eq(int_value)
    token.raw_value.should eq(string)
    token.to_s.should eq(token.raw_value)
  end

  it "lexes #{string} from IO", file, line do
    lexer = JSON::Lexer.new IO::Memory.new(string)
    token = lexer.next_token
    token.kind.should eq(JSON::Token::Kind::Int)
    token.int_value.should eq(int_value)
    token.raw_value.should eq(string)
    token.to_s.should eq(token.raw_value)
  end
end

private def it_lexes_float(string, float_value, file = __FILE__, line = __LINE__)
  it "lexes #{string} from String", file, line do
    lexer = JSON::Lexer.new string
    token = lexer.next_token
    token.kind.should eq(JSON::Token::Kind::Float)
    token.float_value.should eq(float_value)
    token.raw_value.should eq(string)
    token.to_s.should eq(token.raw_value)
  end

  it "lexes #{string} from IO", file, line do
    lexer = JSON::Lexer.new IO::Memory.new(string)
    token = lexer.next_token
    token.kind.should eq(JSON::Token::Kind::Float)
    token.float_value.should eq(float_value)
    token.raw_value.should eq(string)
    token.to_s.should eq(token.raw_value)
  end
end

private def it_errors_to_lex(string, *, file = __FILE__, line = __LINE__)
  it "errors if lexing #{string} from String", file: file, line: line do
    expect_raises(Exception) { JSON::Lexer.new(string).next_token }
  end

  it "errors if lexing #{string} from IO", file: file, line: line do
    expect_raises(Exception) { JSON::Lexer.new(IO::Memory.new(string)).next_token }
  end
end

describe JSON::Lexer do
  it_lexes "", :EOF, expected_to_s: "<EOF>"
  it_lexes "{", :begin_object
  it_lexes "}", :end_object
  it_lexes "[", :begin_array
  it_lexes "]", :end_array
  it_lexes ",", :comma
  it_lexes ":", :colon
  it_lexes " \n\t\r :", :colon, expected_to_s: ":"
  it_lexes "true", :true
  it_lexes "false", :false
  it_lexes "null", :null
  it_lexes_string "\"hello\"", "hello"
  it_lexes_string "\"hello\\\"world\"", "hello\"world"
  it_lexes_string "\"hello\\\\world\"", "hello\\world"
  it_lexes_string "\"hello\\/world\"", "hello/world"
  it_lexes_string "\"hello\\bworld\"", "hello\bworld"
  it_lexes_string "\"hello\\fworld\"", "hello\fworld"
  it_lexes_string "\"hello\\nworld\"", "hello\nworld"
  it_lexes_string "\"hello\\rworld\"", "hello\rworld"
  it_lexes_string "\"hello\\tworld\"", "hello\tworld"
  it_lexes_string "\"\\u201chello world\\u201d\"", "“hello world”"
  it_lexes_string "\"\\uD800\\uDC00\"", 0x10000.unsafe_chr.to_s
  it_lexes_string "\"\\uD840\\uDC00\"", 0x20000.unsafe_chr.to_s
  it_lexes_string "\"\\uDBFF\\uDFFF\"", 0x10ffff.unsafe_chr.to_s
  it_lexes_string "\"\\uD834\\uDD1E\"", "𝄞"
  it_errors_to_lex %("\\uD800")
  it_errors_to_lex %("\\uDC00")
  it_errors_to_lex %("\\uD800\\u0020")
  it_lexes_int "0", 0
  it_lexes_int "1", 1
  it_lexes_int "1234", 1234
  it_lexes_float "0.123", 0.123
  it_lexes_float "1234.567", 1234.567
  it_lexes_float "0e1", 0
  it_lexes_float "0E1", 0
  it_lexes_float "0.1e1", 0.1e1
  it_lexes_float "0e+12", 0
  it_lexes_float "0e-12", 0
  it_lexes_float "1e2", 1e2
  it_lexes_float "1E2", 1e2
  it_lexes_float "1e+12", 1e12
  it_lexes_float "1.2e-3", 1.2e-3
  it_lexes_float "9.91343313498688", 9.91343313498688
  it_lexes_int "-1", -1
  it_lexes_float "-1.23", -1.23
  it_lexes_float "-1.23e4", -1.23e4
  it_lexes_float "-1.23e4", -1.23e4
  it_lexes_float "1000000000000000000.0", 1000000000000000000.0
  it_lexes_float "6000000000000000000.0", 6000000000000000000.0
  it_lexes_float "9000000000000000000.0", 9000000000000000000.0
  it_lexes_float "9876543212345678987654321.0", 9876543212345678987654321.0
  it_lexes_float "9876543212345678987654321e20", 9876543212345678987654321e20
  it_lexes_float "10.100000000000000000000", 10.1
end

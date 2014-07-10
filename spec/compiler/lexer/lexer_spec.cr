#!/usr/bin/env crystal --run
require "../../spec_helper"

def it_lexes(string, type)
  it "lexes #{string.inspect}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(type)
  end
end

def it_lexes(string, type, value)
  it "lexes #{string.inspect}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(type)
    token.value.should eq(value)
  end
end

def it_lexes(string, type, value, number_kind)
  it "lexes #{string.inspect}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(type)
    token.value.should eq(value)
    token.number_kind.should eq(number_kind)
  end
end

def it_lexes_many(values, type)
  values.each do |value|
    it_lexes value, type, value
  end
end

def it_lexes_keywords(keywords)
  keywords.each do |keyword|
    it_lexes keyword.to_s, :IDENT, keyword
  end
end

def it_lexes_idents(idents)
  idents.each do |ident|
    it_lexes ident, :IDENT, ident
  end
end

def it_lexes_i32(values)
  values.each { |value| it_lexes_number :i32, value }
end

def it_lexes_i64(values)
  values.each { |value| it_lexes_number :i64, value }
end

def it_lexes_u64(values)
  values.each { |value| it_lexes_number :u64, value }
end

def it_lexes_f32(values)
  values.each { |value| it_lexes_number :f32, value }
end

def it_lexes_f64(values)
  values.each { |value| it_lexes_number :f64, value }
end

def it_lexes_number(number_kind, value : Array)
  it_lexes value[0], :NUMBER, value[1], number_kind
end

def it_lexes_number(number_kind, value : String)
  it_lexes value, :NUMBER, value, number_kind
end

def it_lexes_char(string, value)
  it "lexes #{string}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(:CHAR)
    (token.value as Char).should eq(value)
  end
end

def it_lexes_operators(ops)
  ops.each do |op|
    it_lexes op.to_s, op
  end
end

def it_lexes_const(value)
  it_lexes value, :CONST, value
end

def it_lexes_instance_var(value)
  it_lexes value, :INSTANCE_VAR, value
end

def it_lexes_class_var(value)
  it_lexes value, :CLASS_VAR, value
end

def it_lexes_globals(globals)
  it_lexes_many globals, :GLOBAL
end

def it_lexes_symbols(symbols)
  symbols.each do |symbol|
    value = symbol[1, symbol.length - 1]
    value = value[1, value.length - 2] if value.starts_with?("\"")
    it_lexes symbol, :SYMBOL, value
  end
end

def it_lexes_regex(regex, exepcted_value = regex[1, regex.length - 2])
  it_lexes regex, :REGEX, exepcted_value
end

def it_lexes_global_match(globals)
  globals.each do |global|
    it_lexes global, :GLOBAL_MATCH, global[1, global.length - 1].to_i
  end
end

def it_raises_doesnt_fit_in_integer(string, message)
  it "errors if can't fit #{string} in integer" do
    lexer = Lexer.new(string)
    begin
      lexer.next_token
      fail "expected to raise"
    rescue ex : Crystal::SyntaxException
      ex.message.should eq(message)
    end
  end
end

describe "Lexer" do
  it_lexes "", :EOF
  it_lexes " ", :SPACE
  it_lexes "\t", :SPACE
  it_lexes "\n", :NEWLINE
  it_lexes "\n\n\n", :NEWLINE
  it_lexes_keywords [:def, :if, :else, :elsif, :end, :true, :false, :class, :module, :include, :extend, :while, :until, :nil, :do, :yield, :return, :unless, :next, :break, :begin, :lib, :fun, :type, :struct, :union, :enum, :macro, :ptr, :out, :require, :case, :when, :then, :of, :abstract, :rescue, :ensure, :is_a?, :alias, :pointerof, :sizeof, :instance_sizeof, :ifdef, :as, :typeof, :for, :in, :undef, :with, :self, :super]
  it_lexes_idents ["ident", "something", "with_underscores", "with_1", "foo?", "bar!", "fooBar", "❨╯°□°❩╯︵┻━┻"]
  it_lexes_idents ["def?", "if?", "else?", "elsif?", "end?", "true?", "false?", "class?", "while?", "nil?", "do?", "yield?", "return?", "unless?", "next?", "break?", "begin?"]
  it_lexes_idents ["def!", "if!", "else!", "elsif!", "end!", "true!", "false!", "class!", "while!", "nil!", "do!", "yield!", "return!", "unless!", "next!", "break!", "begin!"]
  it_lexes_i32 ["1", ["0i32", "0"], ["1hello", "1"], "+1", "-1", "1234", "+1234", "-1234", ["1.foo", "1"], ["1_000", "1000"], ["100_000", "100000"]]
  it_lexes_i64 [["1i64", "1"], ["1_i64", "1"], ["1i64hello", "1"], ["+1_i64", "+1"], ["-1_i64", "-1"]]
  it_lexes_f32 [["0f32", "0"], ["0_f32", "0"], ["1.0f32", "1.0"], ["1.0f32hello", "1.0"], ["+1.0f32", "+1.0"], ["-1.0f32", "-1.0"], ["-0.0f32", "-0.0"], ["1_234.567_890_f32", "1234.567890"]]
  it_lexes_f64 ["1.0", ["1.0hello", "1.0"], "+1.0", "-1.0", ["1_234.567_890", "1234.567890"]]
  it_lexes_f32 [["1e+23_f32", "1e+23"], ["1.2e+23_f32", "1.2e+23"]]
  it_lexes_f64 ["1e23", "1e-23", "1e+23", "1.2e+23", ["1e23f64", "1e23"], ["1.2e+23_f64", "1.2e+23"]]

  it_lexes_number :i8, ["1i8", "1"]
  it_lexes_number :i8, ["1_i8", "1"]

  it_lexes_number :i16, ["1i16", "1"]
  it_lexes_number :i16, ["1_i16", "1"]

  it_lexes_number :i32, ["1i32", "1"]
  it_lexes_number :i32, ["1_i32", "1"]

  it_lexes_number :i64, ["1i64", "1"]
  it_lexes_number :i64, ["1_i64", "1"]

  it_lexes_number :u8, ["1u8", "1"]
  it_lexes_number :u8, ["1_u8", "1"]

  it_lexes_number :u16, ["1u16", "1"]
  it_lexes_number :u16, ["1_u16", "1"]

  it_lexes_number :u32, ["1u32", "1"]
  it_lexes_number :u32, ["1_u32", "1"]

  it_lexes_number :u64, ["1u64", "1"]
  it_lexes_number :u64, ["1_u64", "1"]

  it_lexes_number :f32, ["1f32", "1"]
  it_lexes_number :f32, ["1.0f32", "1.0"]

  it_lexes_number :f64, ["1f64", "1"]
  it_lexes_number :f64, ["1.0f64", "1.0"]

  it_lexes_number :i32, ["0b1010", "10"]
  it_lexes_number :i32, ["+0b1010", "10"]
  it_lexes_number :i32, ["-0b1010", "-10"]

  it_lexes_number :i32, ["0xFFFF", "65535"]
  it_lexes_number :i32, ["0xabcdef", "11259375"]
  it_lexes_number :i32, ["+0xFFFF", "65535"]
  it_lexes_number :i32, ["-0xFFFF", "-65535"]

  it_lexes_number :u64, ["0xFFFF_u64", "65535"]

  it_lexes_i32 [["0123", "83"], ["-0123", "-83"], ["+0123", "83"]]
  it_lexes_f64 [["0.5", "0.5"], ["+0.5", "+0.5"], ["-0.5", "-0.5"]]
  it_lexes_i64 [["0123_i64", "83"], ["0x1_i64", "1"], ["0b1_i64", "1"]]

  it_lexes_i64 ["2147483648", "-2147483649", "-9223372036854775808"]
  it_lexes_u64 ["9223372036854775808", "-9223372036854775809"]

  it_lexes_char "'a'", 'a'
  it_lexes_char "'\\n'", '\n'
  it_lexes_char "'\\t'", '\t'
  it_lexes_char "'\\v'", '\v'
  it_lexes_char "'\\f'", '\f'
  it_lexes_char "'\\r'", '\r'
  it_lexes_char "'\\0'", '\0'
  it_lexes_char "'\\0'", '\0'
  it_lexes_char "'\\''", '\''
  it_lexes_char "'\\\\'", '\\'
  it_lexes_char "'\\1'", '\1'
  it_lexes_operators [:"=", :"<", :"<=", :">", :">=", :"+", :"-", :"*", :"/", :"(", :")", :"==", :"!=", :"=~", :"!", :",", :".", :"..", :"...", :"&&", :"||", :"|", :"{", :"}", :"?", :":", :"+=", :"-=", :"*=", :"/=", :"%=", :"&=", :"|=", :"^=", :"**=", :"<<", :">>", :"%", :"&", :"|", :"^", :"**", :"<<=", :">>=", :"~", :"[]", :"[]=", :"[", :"]", :"::", :"<=>", :"=>", :"||=", :"&&=", :"===", :";", :"->", :"[]?", :"@:", :"{%", :"{{", :"%}"]
  it_lexes "!@foo", :"!"
  it_lexes "+@foo", :"+"
  it_lexes "-@foo", :"-"
  it_lexes_const "Foo"
  it_lexes_instance_var "@foo"
  it_lexes_class_var "@@foo"
  it_lexes_globals ["$foo", "$FOO", "$_foo", "$foo123", "$~"]
  it_lexes_symbols [":foo", ":foo!", ":foo?", ":\"foo\""]
  it_lexes_regex "//", ""
  it_lexes_regex "/foo/"
  it_lexes_regex "/foo\\/bar/", "foo/bar"
  it_lexes_regex "/\\//", "/"
  it_lexes_regex "/foo\\sbar/", "foo\\sbar"
  it_lexes_global_match ["$1", "$10"]

  it_raises_doesnt_fit_in_integer "128_i8", "128 doesn't fit in an Int8"
  it_raises_doesnt_fit_in_integer "-129_i8", "-129 doesn't fit in an Int8"
  it_raises_doesnt_fit_in_integer "256_u8", "256 doesn't fit in an UInt8"
  it_raises_doesnt_fit_in_integer "-1_u8", "Invalid negative value -1 for UInt8"

  it_raises_doesnt_fit_in_integer "32768_i16", "32768 doesn't fit in an Int16"
  it_raises_doesnt_fit_in_integer "-32769_i16", "-32769 doesn't fit in an Int16"
  it_raises_doesnt_fit_in_integer "65536_u16", "65536 doesn't fit in an UInt16"
  it_raises_doesnt_fit_in_integer "-1_u16", "Invalid negative value -1 for UInt16"

  it_raises_doesnt_fit_in_integer "2147483648_i32", "2147483648 doesn't fit in an Int32"
  it_raises_doesnt_fit_in_integer "-2147483649_i32", "-2147483649 doesn't fit in an Int32"
  it_raises_doesnt_fit_in_integer "4294967296_u32", "4294967296 doesn't fit in an UInt32"
  it_raises_doesnt_fit_in_integer "-1_u32", "Invalid negative value -1 for UInt32"

  it_raises_doesnt_fit_in_integer "9223372036854775808_i64", "9223372036854775808 doesn't fit in an Int64"
  it_raises_doesnt_fit_in_integer "-9223372036854775809_i64", "-9223372036854775809 doesn't fit in an Int64"
  it_raises_doesnt_fit_in_integer "118446744073709551616_u64", "118446744073709551616 doesn't fit in an UInt64"
  it_raises_doesnt_fit_in_integer "18446744073709551616_u64", "18446744073709551616 doesn't fit in an UInt64"
  it_raises_doesnt_fit_in_integer "-1_u64", "Invalid negative value -1 for UInt64"

  it_raises_doesnt_fit_in_integer "18446744073709551616", "18446744073709551616 doesn't fit in an UInt64"

  it "lexes not instance var" do
    lexer = Lexer.new "!@foo"
    token = lexer.next_token
    token.type.should eq(:"!")
    token = lexer.next_token
    token.type.should eq(:INSTANCE_VAR)
    token.value.should eq("@foo")
  end

  it "lexes space after keyword" do
    lexer = Lexer.new "end 1"
    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq(:end)
    token = lexer.next_token
    token.type.should eq(:SPACE)
  end

  it "lexes space after char" do
    lexer = Lexer.new "'a' "
    token = lexer.next_token
    token.type.should eq(:CHAR)
    token.value.should eq('a')
    token = lexer.next_token
    token.type.should eq(:SPACE)
  end

  it "lexes comment and token" do
    lexer = Lexer.new "# comment\n="
    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token = lexer.next_token
    token.type.should eq(:"=")
  end

  it "lexes comment at the end" do
    lexer = Lexer.new "# comment"
    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes __LINE__" do
    lexer = Lexer.new "__LINE__"
    token = lexer.next_token
    token.type.should eq(:INT)
    token.value.should eq(1)
  end

  it "lexes __FILE__" do
    lexer = Lexer.new "__FILE__"
    lexer.filename = "foo"
    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("foo")
  end

  it "lexes __DIR__" do
    lexer = Lexer.new "__DIR__"
    lexer.filename = "/Users/foo/bar.cr"
    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("/Users/foo")
  end

  it "lexes dot and ident" do
    lexer = Lexer.new ".read"
    token = lexer.next_token
    token.type.should eq(:".")
    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("read")
    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "raises unterminated regular expression" do
    lexer = Lexer.new("/foo")
    begin
      lexer.next_token
      fail "expected to raise"
    rescue ex : Crystal::SyntaxException
      ex.message.should eq("unterminated regular expression")
    end
  end

  it "raises unterminated quoted symbol" do
    lexer = Lexer.new(":\"foo")
    begin
      lexer.next_token
      fail "expected to raise"
    rescue ex : Crystal::SyntaxException
      ex.message.should eq("unterminated quoted symbol")
    end
  end

  it "lexes utf-8 char" do
    lexer = Lexer.new "'á'"
    token = lexer.next_token
    token.type.should eq(:CHAR)
    (token.value as Char).ord.should eq(225)
  end

  it "lexes utf-8 multibyte char" do
    lexer = Lexer.new "'日'"
    token = lexer.next_token
    token.type.should eq(:CHAR)
    (token.value as Char).ord.should eq(26085)
  end

  it "doesn't raise if slash r with slash n" do
    lexer = Lexer.new("\r\n1")
    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token = lexer.next_token
    token.type.should eq(:NUMBER)
  end

  it "doesn't raise if many slash r with slash n" do
    lexer = Lexer.new("\r\n\r\n\r\n1")
    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token = lexer.next_token
    token.type.should eq(:NUMBER)
  end

  it "raises if slash r without slash n" do
    lexer = Lexer.new("\r1")
    begin
      lexer.next_token
      fail "expected to raise"
    rescue ex : Crystal::SyntaxException
      ex.message.should eq("expected '\\n' after '\\r'")
    end
  end
end

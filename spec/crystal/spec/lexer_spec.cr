#!/usr/bin/env bin/crystal -run
require "spec"
require "../../../bootstrap/crystal/lexer"

def it_lexes(string, type)
  it "lexes #{string}" do
    lexer = Crystal::Lexer.new string
    token = lexer.next_token
    token.type.should eq(type)
  end
end

def it_lexes(string, type, value)
  it "lexes #{string}" do
    lexer = Crystal::Lexer.new string
    token = lexer.next_token
    token.type.should eq(type)
    token.value.should eq(value)
  end
end

def it_lexes_many(values, type)
  values.each do |value|
    it_lexes value, type, value
  end
end

def it_lexes_keywords(keywords)
  it_lexes_many keywords, :IDENT
end

def it_lexes_idents(keywords)
  it_lexes_keywords keywords
end

def it_lexes_ints(values)
  values.each { |value| it_lexes_int value }
end

def it_lexes_int(value : Array)
  it_lexes value[0], :INT, value[1]
end

def it_lexes_int(value)
  it_lexes value, :INT, value
end

def it_lexes_floats(values)
  values.each { |value| it_lexes_float value }
end

def it_lexes_float(value : Array)
  it_lexes value[0], :FLOAT, value[1]
end

def it_lexes_float(value)
  it_lexes value, :FLOAT, value
end

def it_lexes_longs(values)
  values.each { |value| it_lexes_long value }
end

def it_lexes_long(value : Array)
  it_lexes value[0], :LONG, value[1]
end

def it_lexes_long(value)
  it_lexes value, :LONG, value[0, value.length - 1]
end

def it_lexes_char(string, value)
  it "lexes #{string}" do
    lexer = Crystal::Lexer.new string
    token = lexer.next_token
    token.type.should eq(:CHAR)
    token.value.to_s.should eq(value.to_s)
  end
end

def it_lexes_operators(ops)
  it_lexes_many ops, :TOKEN
end

def it_lexes_const(value)
  it_lexes value, :CONST, value
end

def it_lexes_instance_var(value)
  it_lexes value, :INSTANCE_VAR, value
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

def it_lexes_regex(regex)
  it_lexes regex, :REGEXP, regex[1, regex.length - 2]
end

def it_lexes_global_match(globals)
  globals.each do |global|
    it_lexes global, :GLOBAL_MATCH, global[1, global.length - 1].to_i
  end
end

describe "Lexer" do
  it_lexes " ", :SPACE
  it_lexes "\n", :NEWLINE
  it_lexes "\n\n\n", :NEWLINE
  it_lexes_keywords ["def", "if", "else", "elsif", "end", "true", "false", "class", "module", "include", "while", "nil", "do", "yield", "return", "unless", "next", "break", "begin", "lib", "fun", "type", "struct", "macro", "ptr", "out", "require", "case", "when", "generic"]
  it_lexes_idents ["ident", "something", "with_underscores", "with_1", "foo?", "bar!"]
  it_lexes_idents ["def?", "if?", "else?", "elsif?", "end?", "true?", "false?", "class?", "while?", "nil?", "do?", "yield?", "return?", "unless?", "next?", "break?", "begin?"]
  it_lexes_idents ["def!", "if!", "else!", "elsif!", "end!", "true!", "false!", "class!", "while!", "nil!", "do!", "yield!", "return!", "unless!", "next!", "break!", "begin!"]
  it_lexes_ints ["1", ["1hello", "1"], "+1", "-1"]
  it_lexes_floats ["1.0", ["1.0hello", "1.0"], "+1.0", "-1.0"]
  it_lexes_longs ["1L", ["1Lhello", "1"], "+1L", "-1L"]
  it_lexes_char "'a'", 'a'
  it_lexes_char "'\\n'", '\n'
  it_lexes_char "'\\t'", '\t'
  it_lexes_char "'\\0'", '\0'
  it_lexes_operators ["=", "<", "<=", ">", ">=", "+", "-", "*", "/", "(", ")", "==", "!=", "=~", "!", ",", ".", "..", "...", "!@", "+@", "-@", "&&", "||", "|", "{", "}", "?", ":", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "**=", "<<", ">>", "%", "&", "|", "^", "**", "<<=", ">>=", "~", "~@", "[]", "[", "]", "::", "<=>", "=>", "||=", "&&=", "==="]
  it_lexes_const "Foo"
  it_lexes_instance_var "@foo"
  it_lexes_globals ["$foo", "$FOO", "$_foo", "$foo123", "$~"]
  it_lexes_symbols [":foo", ":foo!", ":foo?", ":\"foo\""]
  it_lexes_regex "/foo/"
  it_lexes_global_match ["$1", "$10"]

  it "lexes not instance var" do
    lexer = Crystal::Lexer.new "!@foo"
    token = lexer.next_token
    token.type.should eq(:TOKEN)
    token.value.should eq("!")
    token = lexer.next_token
    token.type.should eq(:INSTANCE_VAR)
    token.value.should eq("@foo")
  end

  it "lexes comment and token" do
    lexer = Crystal::Lexer.new "# comment\n1"
    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token = lexer.next_token
    token.type.should eq(:INT)
    token.value.should eq("1")
  end

  it "lexes comment at the end" do
    lexer = Crystal::Lexer.new "# comment"
    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it "lexes __LINE__" do
    lexer = Crystal::Lexer.new "__LINE__"
    token = lexer.next_token
    token.type.should eq(:INT)
    token.value.should eq(1)
  end

  it "lexes __FILE__" do
    lexer = Crystal::Lexer.new "__FILE__"
    lexer.filename = "foo"
    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq("foo")
  end
end
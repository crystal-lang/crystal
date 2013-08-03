require 'spec_helper'

describe Lexer do
  def self.it_lexes(string, type, value = nil, number_kind = nil)
    it "lexes #{string}" do
      lexer = Lexer.new(string)
      token = lexer.next_token
      token.type.should eq(type)
      token.value.should eq(value)
      token.number_kind.should eq(number_kind)
    end
  end

  def self.it_lexes_operators(*args)
    args.each do |arg|
      it_lexes arg, arg.to_sym
    end
  end

  def self.it_lexes_idents(*args)
    args.each do |arg|
      it_lexes arg, :IDENT, arg
    end
  end

  def self.it_lexes_globals(*args)
    args.each do |arg|
      it_lexes arg, :GLOBAL, arg
    end
  end

  def self.it_lexes_symbols(*args)
    args.each do |arg|
      value = arg[1 .. -1]
      value = value[1 .. -2] if value.start_with?('"')
      it_lexes arg, :SYMBOL, value
    end
  end

  def self.it_lexes_keywords(*args)
    args.each do |arg|
      it_lexes arg, :IDENT, arg.to_sym
    end
  end

  def self.it_lexes_i32(*args)
    it_lexes_numbers :i32, *args
  end

  def self.it_lexes_i64(*args)
    it_lexes_numbers :i64, *args
  end

  def self.it_lexes_f32(*args)
    it_lexes_numbers :f32, *args
  end

  def self.it_lexes_f64(*args)
    it_lexes_numbers :f64, *args
  end

  def self.it_lexes_numbers(number_kind, *args)
    args.each do |arg|
      if arg.is_a? Array
        it_lexes arg[0], :NUMBER, arg[1], number_kind
      else
        arg_match = arg
        if arg.end_with?('_i16') || arg.end_with?('_i32') || arg.end_with?('_i64') ||
           arg.end_with?('_u16') || arg.end_with?('_u32') || arg.end_with?('_u64') ||
           arg.end_with?('_f32') || arg.end_with?('_f64')
          arg_match = arg[0 ... -4]
        elsif arg.end_with?('i16') || arg.end_with?('i32') || arg.end_with?('i64') || arg.end_with?('_i8') ||
              arg.end_with?('u16') || arg.end_with?('u32') || arg.end_with?('u64') || arg.end_with?('_u8') ||
              arg.end_with?('f32') || arg.end_with?('f64')
          arg_match = arg[0 ... -3]
        elsif arg.end_with?('i8') || arg.end_with?('u8')
          arg_match = arg[0 ... -2]
        end
        it_lexes arg, :NUMBER, arg_match, number_kind
      end
    end
  end

  def self.it_lexes_char(string, value)
    it_lexes string, :CHAR, value
  end

  def self.it_lexes_const(string)
    it_lexes string, :CONST, string
  end

  def self.it_lexes_instance_var(string)
    it_lexes string, :INSTANCE_VAR, string
  end

  def self.it_lexes_regex(string)
    it_lexes string, :REGEXP, string[1 .. -2]
  end

  def self.it_lexes_global_match(*args)
    args.each do |arg|
      it_lexes arg, :GLOBAL_MATCH, arg[1 .. -1].to_i
    end
  end

  it_lexes " ", :SPACE
  it_lexes "\n", :NEWLINE
  it_lexes "\n\n\n", :NEWLINE
  it_lexes_keywords "def", "if", "else", "elsif", "end", "true", "false", "class", "module", "include", "while", "nil", "do", "yield", "return", "unless", "next", "break", "begin", "lib", "fun", "type", "struct", "union", "enum", "macro", "out", "require", "case", "when", "then", "of", "abstract"
  it_lexes_idents "ident", "something", "with_underscores", "with_1", "foo?", "bar!"
  it_lexes_idents "def?", "if?", "else?", "elsif?", "end?", "true?", "false?", "class?", "while?", "nil?", "do?", "yield?", "return?", "unless?", "next?", "break?", "begin?"
  it_lexes_idents "def!", "if!", "else!", "elsif!", "end!", "true!", "false!", "class!", "while!", "nil!", "do!", "yield!", "return!", "unless!", "next!", "break!", "begin!"
  it_lexes_i32 "1", ["1hello", "1"], ["1_000", "1000"], ["100_000", "100000"], ["1__0", "1"], "+1", "-1"
  it_lexes_i64 "1i64", ["1i64hello", "1"], ["1_000i64", "1000"], "+1_i64", "-1_i64"
  it_lexes_f32 "1.0f32", ["1.0f32hello", "1.0"], ["1234.567_890f32", "1234.567890"], ["1_234.567_890_f32", "1234.567890"], "+1.0f32", "-1.0f32"
  it_lexes_f32 "1e10f32", "1.0e+12f32", "+1.0e-12f32", "-2.0e+34f32", ["-1_000.0e+34f32", "-1000.0e+34"]
  it_lexes_f64 "1.0", ["1.0hello", "1.0"], ["1234.567_890", "1234.567890"], ["1_234.567_890", "1234.567890"], "+1.0", "-1.0"
  it_lexes_f64 "1e10", "1.0e+12", "+1.0e-12", "-2.0e+34", ["-1_000.0e+34", "-1000.0e+34"]

  it_lexes_numbers :i8, "1i8", "1_i8"
  it_lexes_numbers :i16, "1i16", "1_i16"
  it_lexes_numbers :i32, "132", "1_i32"
  it_lexes_numbers :i64, "1i64", "1_i64"

  it_lexes_numbers :u8, "1u8", "1_u8"
  it_lexes_numbers :u16, "1u16", "1_u16"
  it_lexes_numbers :u32, "1u32", "1_u32"
  it_lexes_numbers :u64, "1u64", "1_u64"

  it_lexes_numbers :f32, "1f32", "1_f32"
  it_lexes_numbers :f64, "1f64", "1_f64"

  it_lexes_numbers :i32, ["0b1010", "10"]
  it_lexes_numbers :i32, ["0xFFFF", "65535"], ["0xabcdef", "11259375"]
  it_lexes_numbers :u32, ["0x80000000", "2147483648"], ["0xFFFFFFFF", "4294967295"]
  it_lexes_numbers :i64, ["0x100000000", "4294967296"], ["0x7FFFFFFFFFFFFFFF", "9223372036854775807"]
  it_lexes_numbers :u64, ["0x8000000000000000", "9223372036854775808"], ["0xFFFFFFFFFFFFFFFF", "18446744073709551615"]

  it_lexes_numbers :u32, "2147483648", "4294967295"
  it_lexes_numbers :i64, "4294967296", "9223372036854775807"
  it_lexes_numbers :u64, "9223372036854775808", "18446744073709551615"

  it_lexes_char "'a'", ?a.ord
  it_lexes_char "'\\n'", ?\n.ord
  it_lexes_char "'\\t'", ?\t.ord
  it_lexes_char "'\\r'", ?\r.ord
  it_lexes_char "'\\0'", ?\0.ord
  it_lexes_char "'\\''", ?'.ord
  it_lexes_char "'\\\\'", "\\".ord
  it_lexes_operators "=", "<", "<=", ">", ">=", "+", "-", "*", "/", "(", ")", "==", "!=", '=~', "!", ",", '.', '..', '...', "!@", "+@", "-@", "&&", "||", "|", "{", "}", '?', ':', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '**=', '<<', '>>', '%', '&', '|', '^', '**', '<<=', '>>=', '~', '~@', '[]', '[', ']', '::', '<=>', '=>', '||=', '&&=', '===', '->'
  it_lexes_const "Foo"
  it_lexes_instance_var "@foo"
  it_lexes_globals "$foo", "$FOO", "$_foo", "$foo123", "$~"
  it_lexes_symbols ":foo", ":foo!", ":foo?", %q(:"foo")
  it_lexes_regex "/foo/"
  it_lexes_global_match "$1", "$10"

  it "lexer not instance var" do
    lexer = Lexer.new "!@foo"
    token = lexer.next_token
    token.type.should eq(:'!')
    token = lexer.next_token
    token.type.should eq(:INSTANCE_VAR)
    token.value.should eq('@foo')
  end

  it "lexes comment and token" do
    lexer = Lexer.new "# comment\n1"
    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token = lexer.next_token
    token.type.should eq(:NUMBER)
    token.number_kind.should eq(:i32)
    token.value.should eq("1")
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
    lexer.filename = 'foo'
    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq('foo')
  end

  it "lexes __DIR__" do
    lexer = Lexer.new "__DIR__"
    lexer.filename = '/Users/foo/bar.cr'
    token = lexer.next_token
    token.type.should eq(:STRING)
    token.value.should eq('/Users/foo')
  end
end

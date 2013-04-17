require 'spec_helper'

describe Lexer do
  def self.it_lexes(string, type, value = nil)
    it "lexes #{string}" do
      lexer = Lexer.new(string)
      token = lexer.next_token
      token.type.should eq(type)
      token.value.should eq(value)
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

  def self.it_lexes_ints(*args)
    args.each do |arg|
      if arg.is_a? Array
        it_lexes arg[0], :INT, arg[1]
      else
        it_lexes arg, :INT, arg
      end
    end
  end

  def self.it_lexes_floats(*args)
    args.each do |arg|
      if arg.is_a? Array
        it_lexes arg[0], :FLOAT, arg[1]
      else
        it_lexes arg, :FLOAT, arg[0 .. -2]
      end
    end
  end

  def self.it_lexes_doubles(*args)
    args.each do |arg|
      if arg.is_a? Array
        it_lexes arg[0], :DOUBLE, arg[1]
      else
        it_lexes arg, :DOUBLE, arg
      end
    end
  end

  def self.it_lexes_longs(*args)
    args.each do |arg|
      if arg.is_a? Array
        it_lexes arg[0], :LONG, arg[1]
      else
        it_lexes arg, :LONG, arg[0 ... -1]
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
  it_lexes_keywords "def", "if", "else", "elsif", "end", "true", "false", "class", "module", "include", "while", "nil", "do", "yield", "return", "unless", "next", "break", "begin", "lib", "fun", "type", "struct", "macro", "out", "require", "case", "when", "then"
  it_lexes_idents "ident", "something", "with_underscores", "with_1", "foo?", "bar!"
  it_lexes_idents "def?", "if?", "else?", "elsif?", "end?", "true?", "false?", "class?", "while?", "nil?", "do?", "yield?", "return?", "unless?", "next?", "break?", "begin?"
  it_lexes_idents "def!", "if!", "else!", "elsif!", "end!", "true!", "false!", "class!", "while!", "nil!", "do!", "yield!", "return!", "unless!", "next!", "break!", "begin!"
  it_lexes_ints "1", ["1hello", "1"], ["1_000", "1000"], ["100_000", "100000"], ["1__0", "1"], "+1", "-1"
  it_lexes_floats "1.0f", ["1.0fhello", "1.0"], ["1234.567_890f", "1234.567890"], ["1_234.567_890f", "1234.567890"], "+1.0f", "-1.0f"
  it_lexes_floats "1e10f", "1.0e+12f", "+1.0e-12f", "-2.0e+34f", ["-1_000.0e+34f", "-1000.0e+34"]
  it_lexes_doubles "1.0", ["1.0hello", "1.0"], ["1234.567_890", "1234.567890"], ["1_234.567_890", "1234.567890"], "+1.0", "-1.0"
  it_lexes_doubles "1e10", "1.0e+12", "+1.0e-12", "-2.0e+34", ["-1_000.0e+34", "-1000.0e+34"]
  it_lexes_longs "1L", ["1Lhello", "1"], ["1_000L", "1000"], "+1L", "-1L"
  it_lexes_char "'a'", ?a.ord
  it_lexes_char "'\\n'", ?\n.ord
  it_lexes_char "'\\t'", ?\t.ord
  it_lexes_char "'\\r'", ?\r.ord
  it_lexes_char "'\\0'", ?\0.ord
  it_lexes_char "'\\''", ?'.ord
  it_lexes_char "'\\\\'", "\\".ord
  it_lexes_operators "=", "<", "<=", ">", ">=", "+", "-", "*", "/", "(", ")", "==", "!=", '=~', "!", ",", '.', '..', '...', "!@", "+@", "-@", "&&", "||", "|", "{", "}", '?', ':', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '**=', '<<', '>>', '%', '&', '|', '^', '**', '<<=', '>>=', '~', '~@', '[]', '[', ']', '::', '<=>', '=>', '||=', '&&=', '==='
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
    token.type.should eq(:INT)
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
end

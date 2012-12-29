require "spec"
require "../../../bootstrap/crystal/lexer"

def it_lexes(string, token_type)
  it "lexes #{string}" do
    lexer = Crystal::Lexer.new string
    token = lexer.next_token
    token.type.should eq(token_type)
  end
end

def it_lexes(string, token_type, token_value)
  it "lexes #{string}" do
    lexer = Crystal::Lexer.new string
    token = lexer.next_token
    token.type.should eq(token_type)
    token.value.should eq(token_value)
  end
end

def it_lexes_keywords(keywords)
  keywords.each do |keyword|
    it_lexes keyword, :IDENT, keyword
  end
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
  ops.each do |op|
    it_lexes op, :TOKEN, op
  end
end

describe "Lexer" do
  it_lexes " ", :SPACE
  it_lexes "\n", :NEWLINE
  it_lexes "\n\n\n", :NEWLINE
  it_lexes_keywords ["def", "if", "else", "elsif", "end", "true", "false", "class", "module", "include", "while", "nil", "do", "yield", "return", "unless", "next", "break", "begin", "lib", "fun", "type", "struct", "macro", "ptr", "out", "require", "case", "when"]
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
end
require "../../spec_helper"

describe "Lexer macro" do
  it "lexes simple macro" do
    lexer = Lexer.new(%(hello end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("hello ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with expression" do
    lexer = Lexer.new(%(hello {{world}} end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("hello ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    lexer.next_token.type.should eq(:"}")
    lexer.next_token.type.should eq(:"}")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(" ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  %w(begin do if unless class struct module def while until case macro fun lib union).each do |keyword|
    it "lexes macro with nested #{keyword}" do
      lexer = Lexer.new(%(hello\n  #{keyword} {{world}} end end))

      token = lexer.next_macro_token(Token::MacroState.default, false)
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq("hello\n  #{keyword} ")
      token.macro_state.nest.should eq(1)

      token = lexer.next_macro_token(token.macro_state, false)
      token.type.should eq(:MACRO_EXPRESSION_START)

      token_before_expression = token.clone

      token = lexer.next_token
      token.type.should eq(:IDENT)
      token.value.should eq("world")

      lexer.next_token.type.should eq(:"}")
      lexer.next_token.type.should eq(:"}")

      token = lexer.next_macro_token(token_before_expression.macro_state, false)
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq(" ")

      token = lexer.next_macro_token(token.macro_state, false)
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq("end ")

      token = lexer.next_macro_token(token.macro_state, false)
      token.type.should eq(:MACRO_END)
    end
  end

  it "lexes macro with nested enum" do
    lexer = Lexer.new(%(hello enum {{world}} end end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("hello ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("enum ")
    token.macro_state.nest.should eq(1)

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    lexer.next_token.type.should eq(:"}")
    lexer.next_token.type.should eq(:"}")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(" ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("end ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro without nested if" do
    lexer = Lexer.new(%(helloif {{world}} end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("helloif ")
    token.macro_state.nest.should eq(0)

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("world")

    lexer.next_token.type.should eq(:"}")
    lexer.next_token.type.should eq(:"}")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(" ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "reaches end" do
    lexer = Lexer.new(%(fail))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("fail")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:EOF)
  end

  it "keeps correct column and line numbers" do
    lexer = Lexer.new("\nfoo\nbarf{{var}}\nend")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("\nfoo\nbarf")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("var")
    token.line_number.should eq(3)
    token.column_number.should eq(7)

    lexer.next_token.type.should eq(:"}")
    lexer.next_token.type.should eq(:"}")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("\n")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with control" do
    lexer = Lexer.new("foo{% if ")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("foo")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_CONTROL_START)
  end

  it "skips whitespace" do
    lexer = Lexer.new("   \n    coco")

    token = lexer.next_macro_token(Token::MacroState.default, true)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("coco")
  end

  it "lexes macro with embedded string" do
    lexer = Lexer.new(%(good " end " day end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(%(good " end " day ))

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with embedded string and backslash" do
    lexer = Lexer.new("good \" end \\\" \" day end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("good \" end \\\" \" day ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with embedded string and expression" do
    lexer = Lexer.new(%(good " end {{foo}} " day end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(%(good " end ))

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_EXPRESSION_START)

    macro_state = token.macro_state

    token = lexer.next_token
    token.type.should eq(:IDENT)
    token.value.should eq("foo")

    lexer.next_token.type.should eq(:"}")
    lexer.next_token.type.should eq(:"}")

    token = lexer.next_macro_token(macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(%( " day ))

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  [{"(", ")"}, {"[", "]"}, {"<", ">"}].each do |tuple|
    it "lexes macro with embedded string with %#{tuple[0]}" do
      lexer = Lexer.new("good %#{tuple[0]} end #{tuple[1]} day end")

      token = lexer.next_macro_token(Token::MacroState.default, false)
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq("good %#{tuple[0]} end #{tuple[1]} day ")

      token = lexer.next_macro_token(token.macro_state, false)
      token.type.should eq(:MACRO_END)
    end

    it "lexes macro with embedded string with %#{tuple[0]} ignores begin" do
      lexer = Lexer.new("good %#{tuple[0]} begin #{tuple[1]} day end")

      token = lexer.next_macro_token(Token::MacroState.default, false)
      token.type.should eq(:MACRO_LITERAL)
      token.value.should eq("good %#{tuple[0]} begin #{tuple[1]} day ")

      token = lexer.next_macro_token(token.macro_state, false)
      token.type.should eq(:MACRO_END)
    end
  end

  it "lexes macro with nested embedded string with %(" do
    lexer = Lexer.new("good %( ( ) end ) day end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("good %( ( ) end ) day ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with comments" do
    lexer = Lexer.new("good # end\n day end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("good ")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("\n day ")
    token.line_number.should eq(2)

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with curly escape" do
    lexer = Lexer.new("good \\{{world}}\nend")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("good ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("{")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("{world}}\n")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with if as suffix" do
    lexer = Lexer.new("foo if bar end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("foo if bar ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with if as suffix after return" do
    lexer = Lexer.new("return if @end end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("return if @end ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with semicolon before end" do
    lexer = Lexer.new(";end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq(";")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end

  it "lexes macro with if after assign" do
    lexer = Lexer.new("x = if 1; 2; else; 3; end; end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("x = if 1; 2; ")
    token.macro_state.nest.should eq(1)

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("else; 3; ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_LITERAL)
    token.value.should eq("end; ")

    token = lexer.next_macro_token(token.macro_state, false)
    token.type.should eq(:MACRO_END)
  end
end

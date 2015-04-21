require "../../spec_helper"

describe "Lexer macro" do
  it "lexes simple macro" do
    lexer = Lexer.new(%(hello end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("hello ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with expression" do
    lexer = Lexer.new(%(hello {{world}} end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("hello ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    expect(token.type).to eq(:IDENT)
    expect(token.value).to eq("world")

    expect(lexer.next_token.type).to eq(:"}")
    expect(lexer.next_token.type).to eq(:"}")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(" ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  ["begin", "do", "if", "unless", "class", "struct", "module", "def", "while", "until", "case", "macro", "fun", "lib", "union", "ifdef", "macro def"].each do |keyword|
    it "lexes macro with nested #{keyword}" do
      lexer = Lexer.new(%(hello\n  #{keyword} {{world}} end end))

      token = lexer.next_macro_token(Token::MacroState.default, false)
      expect(token.type).to eq(:MACRO_LITERAL)
      expect(token.value).to eq("hello\n  #{keyword} ")
      expect(token.macro_state.nest).to eq(1)

      token = lexer.next_macro_token(token.macro_state, false)
      expect(token.type).to eq(:MACRO_EXPRESSION_START)

      token_before_expression = token.clone

      token = lexer.next_token
      expect(token.type).to eq(:IDENT)
      expect(token.value).to eq("world")

      expect(lexer.next_token.type).to eq(:"}")
      expect(lexer.next_token.type).to eq(:"}")

      token = lexer.next_macro_token(token_before_expression.macro_state, false)
      expect(token.type).to eq(:MACRO_LITERAL)
      expect(token.value).to eq(" ")

      token = lexer.next_macro_token(token.macro_state, false)
      expect(token.type).to eq(:MACRO_LITERAL)
      expect(token.value).to eq("end ")

      token = lexer.next_macro_token(token.macro_state, false)
      expect(token.type).to eq(:MACRO_END)
    end
  end

  it "lexes macro with nested enum" do
    lexer = Lexer.new(%(hello enum {{world}} end end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("hello ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("enum ")
    expect(token.macro_state.nest).to eq(1)

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    expect(token.type).to eq(:IDENT)
    expect(token.value).to eq("world")

    expect(lexer.next_token.type).to eq(:"}")
    expect(lexer.next_token.type).to eq(:"}")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(" ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("end ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro without nested if" do
    lexer = Lexer.new(%(helloif {{world}} end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("helloif ")
    expect(token.macro_state.nest).to eq(0)

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    expect(token.type).to eq(:IDENT)
    expect(token.value).to eq("world")

    expect(lexer.next_token.type).to eq(:"}")
    expect(lexer.next_token.type).to eq(:"}")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(" ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

    it "lexes macro with nested abstract def" do
      lexer = Lexer.new(%(hello\n  abstract def {{world}} end end))

      token = lexer.next_macro_token(Token::MacroState.default, false)
      expect(token.type).to eq(:MACRO_LITERAL)
      expect(token.value).to eq("hello\n  abstract def ")
      expect(token.macro_state.nest).to eq(0)

      token = lexer.next_macro_token(token.macro_state, false)
      expect(token.type).to eq(:MACRO_EXPRESSION_START)

      token_before_expression = token.clone

      token = lexer.next_token
      expect(token.type).to eq(:IDENT)
      expect(token.value).to eq("world")

      expect(lexer.next_token.type).to eq(:"}")
      expect(lexer.next_token.type).to eq(:"}")

      token = lexer.next_macro_token(token_before_expression.macro_state, false)
      expect(token.type).to eq(:MACRO_LITERAL)
      expect(token.value).to eq(" ")

      token = lexer.next_macro_token(token.macro_state, false)
      expect(token.type).to eq(:MACRO_END)
    end

  it "reaches end" do
    lexer = Lexer.new(%(fail))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("fail")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:EOF)
  end

  it "keeps correct column and line numbers" do
    lexer = Lexer.new("\nfoo\nbarf{{var}}\nend")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("\nfoo\nbarf")
    expect(token.column_number).to eq(1)
    expect(token.line_number).to eq(1)

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_EXPRESSION_START)

    token_before_expression = token.clone

    token = lexer.next_token
    expect(token.type).to eq(:IDENT)
    expect(token.value).to eq("var")
    expect(token.line_number).to eq(3)
    expect(token.column_number).to eq(7)

    expect(lexer.next_token.type).to eq(:"}")
    expect(lexer.next_token.type).to eq(:"}")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("\n")

    token = lexer.next_macro_token(token_before_expression.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with control" do
    lexer = Lexer.new("foo{% if ")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("foo")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_CONTROL_START)
  end

  it "skips whitespace" do
    lexer = Lexer.new("   \n    coco")

    token = lexer.next_macro_token(Token::MacroState.default, true)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("coco")
  end

  it "lexes macro with embedded string" do
    lexer = Lexer.new(%(good " end " day end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(%(good " end " day ))

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with embedded string and backslash" do
    lexer = Lexer.new("good \" end \\\" \" day end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("good \" end \\\" \" day ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with embedded string and expression" do
    lexer = Lexer.new(%(good " end {{foo}} " day end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(%(good " end ))

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_EXPRESSION_START)

    macro_state = token.macro_state

    token = lexer.next_token
    expect(token.type).to eq(:IDENT)
    expect(token.value).to eq("foo")

    expect(lexer.next_token.type).to eq(:"}")
    expect(lexer.next_token.type).to eq(:"}")

    token = lexer.next_macro_token(macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(%( " day ))

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  [{"(", ")"}, {"[", "]"}, {"<", ">"}].each do |tuple|
    it "lexes macro with embedded string with %#{tuple[0]}" do
      lexer = Lexer.new("good %#{tuple[0]} end #{tuple[1]} day end")

      token = lexer.next_macro_token(Token::MacroState.default, false)
      expect(token.type).to eq(:MACRO_LITERAL)
      expect(token.value).to eq("good %#{tuple[0]} end #{tuple[1]} day ")

      token = lexer.next_macro_token(token.macro_state, false)
      expect(token.type).to eq(:MACRO_END)
    end

    it "lexes macro with embedded string with %#{tuple[0]} ignores begin" do
      lexer = Lexer.new("good %#{tuple[0]} begin #{tuple[1]} day end")

      token = lexer.next_macro_token(Token::MacroState.default, false)
      expect(token.type).to eq(:MACRO_LITERAL)
      expect(token.value).to eq("good %#{tuple[0]} begin #{tuple[1]} day ")

      token = lexer.next_macro_token(token.macro_state, false)
      expect(token.type).to eq(:MACRO_END)
    end
  end

  it "lexes macro with nested embedded string with %(" do
    lexer = Lexer.new("good %( ( ) end ) day end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("good %( ( ) end ) day ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with comments" do
    lexer = Lexer.new("good # end\n day end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("good ")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("\n day ")
    expect(token.line_number).to eq(2)

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with curly escape" do
    lexer = Lexer.new("good \\{{world}}\nend")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("good ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("{")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("{world}}\n")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with if as suffix" do
    lexer = Lexer.new("foo if bar end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("foo if bar ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with if as suffix after return" do
    lexer = Lexer.new("return if @end end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("return if @end ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with semicolon before end" do
    lexer = Lexer.new(";end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(";")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro with if after assign" do
    lexer = Lexer.new("x = if 1; 2; else; 3; end; end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("x = if 1; 2; ")
    expect(token.macro_state.nest).to eq(1)

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("else; 3; ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("end; ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro var" do
    lexer = Lexer.new("x = if %var; 2; else; 3; end; end")

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("x = if ")
    expect(token.macro_state.nest).to eq(1)

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_VAR)
    expect(token.value).to eq("var")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("; 2; ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("else; 3; ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq("end; ")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end

  it "lexes macro var inside string" do
    lexer = Lexer.new(%(" %var " end))

    token = lexer.next_macro_token(Token::MacroState.default, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(%(" ))
    expect(token.macro_state.nest).to eq(0)
    expect(token.macro_state.delimiter_state.not_nil!.nest).to eq('"')

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_VAR)
    expect(token.value).to eq("var")

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_LITERAL)
    expect(token.value).to eq(%( " ))

    token = lexer.next_macro_token(token.macro_state, false)
    expect(token.type).to eq(:MACRO_END)
  end
end

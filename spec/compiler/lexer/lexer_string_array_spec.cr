require "../../support/syntax"

private def t(kind : Crystal::Token::Kind)
  kind
end

private def it_should_be_valid_string_array_lexer(lexer)
  token = lexer.next_token
  token.type.should eq(t :STRING_ARRAY_START)

  token = lexer.next_string_token(token.delimiter_state)
  token.type.should eq(t :STRING)
  token.value.should eq("one")

  token = lexer.next_string_token(token.delimiter_state)
  token.type.should eq(t :SPACE)
  token.value.should eq(" ")

  token = lexer.next_string_token(token.delimiter_state)
  token.type.should eq(t :STRING)
  token.value.should eq("two")

  token = lexer.next_string_token(token.delimiter_state)
  token.type.should eq(t :STRING_ARRAY_END)
end

describe "Lexer %w string array" do
  it "lexes simple string array" do
    lexer = Lexer.new("%w(one two)")

    it_should_be_valid_string_array_lexer(lexer)
  end

  it "lexes string array with new line" do
    lexer = Lexer.new("%w(one \n two)")

    token = lexer.next_token
    token.type.should eq(t :STRING_ARRAY_START)

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :STRING)
    token.value.should eq("one")

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :SPACE)
    token.value.should eq(" \n ")

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :STRING)
    token.value.should eq("two")

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :STRING_ARRAY_END)
  end

  it "lexes string array with new line gives correct column for next token" do
    lexer = Lexer.new("%w(one \n two).")

    token = lexer.next_token
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)

    token = lexer.next_token
    token.line_number.should eq(2)
    token.column_number.should eq(6)
  end

  context "using { as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%w{one two}")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using [ as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%w[one two]")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using < as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%w<one two>")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using | as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%w|one two|")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end
end

describe "Lexer %W string array" do
  it "lexes simple string array" do
    lexer = Lexer.new("%W(one two)")

    it_should_be_valid_string_array_lexer(lexer)
  end

  it "lexes string array with new line" do
    lexer = Lexer.new("%W(one \n two)")

    token = lexer.next_token
    token.type.should eq(t :STRING_ARRAY_START)

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :STRING)
    token.value.should eq("one")

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :SPACE)
    token.value.should eq(" \n ")

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :STRING)
    token.value.should eq("two")

    token = lexer.next_string_token(token.delimiter_state)
    token.type.should eq(t :STRING_ARRAY_END)
  end

  it "lexes string array with new line gives correct column for next token" do
    lexer = Lexer.new("%W(one \n two)")

    token = lexer.next_token
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)

    token = lexer.next_token
    token.line_number.should eq(2)
    token.column_number.should eq(3)
  end

  it "lexes string array with interpolation" do
    lexer = Lexer.new("%W(one \#{two} three)")

    token = lexer.next_token
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)
    lexer.next_token
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)
    lexer.next_string_token(token.delimiter_state)

    token = lexer.next_token
    token.line_number.should eq(1)
    token.column_number.should eq(21)
  end

  context "using { as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%W{one two}")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using [ as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%W[one two]")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using < as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%W<one two>")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end

  context "using | as delimiter" do
    it "lexes simple string array" do
      lexer = Lexer.new("%W|one two|")

      it_should_be_valid_string_array_lexer(lexer)
    end
  end
end

require "spec"
require "ecr/lexer"

private def t(type : ECR::Lexer::Token::Type)
  type
end

describe "ECR::Lexer" do
  it "lexes without interpolation" do
    lexer = ECR::Lexer.new("hello")

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("hello")
    token.line_number.should eq(1)
    token.column_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :eof)
  end

  it "lexes with <% %>" do
    lexer = ECR::Lexer.new("hello <% foo %> bar")

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("hello ")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :control)
    token.value.should eq(" foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(9)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_false

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq(" bar")
    token.line_number.should eq(1)
    token.column_number.should eq(16)

    token = lexer.next_token
    token.type.should eq(t :eof)
  end

  it "lexes with <%- %>" do
    lexer = ECR::Lexer.new("<%- foo %>")

    token = lexer.next_token
    token.type.should eq(t :control)
    token.value.should eq(" foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(4)
    token.suppress_leading?.should be_true
    token.suppress_trailing?.should be_false
  end

  it "lexes with <% -%>" do
    lexer = ECR::Lexer.new("<% foo -%>")

    token = lexer.next_token
    token.type.should eq(t :control)
    token.value.should eq(" foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(3)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_true
  end

  it "lexes with -% inside string" do
    lexer = ECR::Lexer.new("<% \"-%\" %>")

    token = lexer.next_token
    token.type.should eq(t :control)
    token.value.should eq(" \"-%\" ")
  end

  it "lexes with <%= %>" do
    lexer = ECR::Lexer.new("hello <%= foo %> bar")

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("hello ")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(ECR::Lexer::Token::Type::Output)
    token.value.should eq(" foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(10)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_false

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq(" bar")
    token.line_number.should eq(1)
    token.column_number.should eq(17)

    token = lexer.next_token
    token.type.should eq(t :eof)
  end

  it "lexes with <%= -%>" do
    lexer = ECR::Lexer.new("<%= foo -%>")

    token = lexer.next_token
    token.type.should eq(ECR::Lexer::Token::Type::Output)
    token.value.should eq(" foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(4)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_true
  end

  it "lexes with <%# %>" do
    lexer = ECR::Lexer.new("hello <%# foo %> bar")

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("hello ")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :control)
    token.value.should eq("# foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(9)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_false

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq(" bar")
    token.line_number.should eq(1)
    token.column_number.should eq(17)

    token = lexer.next_token
    token.type.should eq(t :eof)
  end

  it "lexes with <%# -%>" do
    lexer = ECR::Lexer.new("<%# foo -%>")

    token = lexer.next_token
    token.type.should eq(t :control)
    token.value.should eq("# foo ")
    token.line_number.should eq(1)
    token.column_number.should eq(3)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_true
  end

  it "lexes with <%% %>" do
    lexer = ECR::Lexer.new("hello <%% foo %> bar")

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("hello ")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("<% foo %>")
    token.line_number.should eq(1)
    token.column_number.should eq(10)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_false

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq(" bar")
    token.line_number.should eq(1)
    token.column_number.should eq(17)

    token = lexer.next_token
    token.type.should eq(t :eof)
  end

  it "lexes with <%%= %>" do
    lexer = ECR::Lexer.new("hello <%%= foo %> bar")

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("hello ")
    token.column_number.should eq(1)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("<%= foo %>")
    token.line_number.should eq(1)
    token.column_number.should eq(10)
    token.suppress_leading?.should be_false
    token.suppress_trailing?.should be_false

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq(" bar")
    token.line_number.should eq(1)
    token.column_number.should eq(18)

    token = lexer.next_token
    token.type.should eq(t :eof)
  end

  it "lexes with <% %> and correct location info" do
    lexer = ECR::Lexer.new("hi\nthere <% foo\nbar %> baz")

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq("hi\nthere ")
    token.line_number.should eq(1)
    token.column_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(t :control)
    token.value.should eq(" foo\nbar ")
    token.line_number.should eq(2)
    token.column_number.should eq(9)

    token = lexer.next_token
    token.type.should eq(t :string)
    token.value.should eq(" baz")
    token.line_number.should eq(3)
    token.column_number.should eq(7)

    token = lexer.next_token
    token.type.should eq(t :eof)
  end
end

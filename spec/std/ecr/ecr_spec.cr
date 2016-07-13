require "spec"
require "ecr"
require "ecr/processor"

class ECRSpecHelloView
  @msg : String

  def initialize(@msg)
  end

  ECR.def_to_s "#{__DIR__}/../data/test_template.ecr"
end

describe "ECR" do
  it "builds a crystal program from a source" do
    program = ECR.process_string "hello <%= 1 %> wor\nld <% while true %> 2 <% end %>\n<%# skip %> <%% \"string\" %>", "foo.cr"

    pieces = [
      %(__str__ << "hello "),
      %((#<loc:"foo.cr",1,9>1).to_s __str__),
      %(__str__ << " wor\\n"),
      %(__str__ << \"ld \"),
      %(#<loc:"foo.cr",2,6> while true),
      %(__str__ << " 2 "),
      %(#<loc:"foo.cr",2,25> end),
      %(__str__ << "\\n"),
      %(#<loc:\"foo.cr\",3,3> # skip),
      %(__str__ << " "),
      %(__str__ << "<% \\"string\\" %>"),
    ]
    program.should eq(pieces.join("\n") + "\n")
  end

  it "does ECR.def_to_s" do
    view = ECRSpecHelloView.new("world!")
    view.to_s.should eq("  Hello world! 012\n")
  end

  it "skips newlines" do
    program = ECR.process_string "<% [1, 2].each do |num| -%>
  <%= num %>
  <% end -%>", "foo.cr"
    pieces = [
      %(#<loc:\"foo.cr\",1,3> [1, 2].each do |num|\n__str__ << \"  \"),
      %((#<loc:\"foo.cr\",2,5>num).to_s __str__),
      %(__str__ << \"\\n\"),
      %(__str__ << \"  \"),
      %(#<loc:\"foo.cr\",3,5> end)
    ]
    program.should eq(pieces.join("\n") + "\n")
  end
  
  describe "Token" do
    
    it "suppresses leading whitepace" do
      token = ECR::Lexer::Token.new
      token.type = :CONTROL
      token.value = "- foo"
      token.suppress_leading?.should be_true
      token.value.should eq("foo")
    end
    
    it "suppresses trailing whitepace" do
      token = ECR::Lexer::Token.new
      token.type = :CONTROL
      token.value = "foo -"
      token.suppress_trailing?.should be_true
      token.value.should eq("foo")
    end
    
    it "is output" do
      token = ECR::Lexer::Token.new
      token.type = :CONTROL
      token.value = "= foo"
      token.is_output?.should be_true
      token.value.should eq("foo")
    end
    
    it "is escape" do
      token = ECR::Lexer::Token.new
      token.type = :CONTROL
      token.value = "% foo "
      token.is_escape?.should be_true
      token.value.should eq("<% foo %>")

    end
    
    it "is string" do
      token = ECR::Lexer::Token.new
      token.type = :STRING
      token.value = "= foo "
      token.is_escape?.should be_false
      token.is_output?.should be_false
      token.value.should eq("= foo ")
    end
    
    it "is whitespace" do
      token = ECR::Lexer::Token.new
      token.type = :STRING
      token.value = "  \n     "
      token.is_whitespace?.should be_true
    end

  end

end

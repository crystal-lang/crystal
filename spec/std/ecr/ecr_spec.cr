require "spec"
require "ecr"
require "ecr/processor"

private class ECRSpecHelloView
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
      %(#<loc:push>(#<loc:"foo.cr",1,10> 1 )#<loc:pop>.to_s __str__),
      %(__str__ << " wor\\nld "),
      %(#<loc:push>#<loc:"foo.cr",2,6> while true #<loc:pop>),
      %(__str__ << " 2 "),
      %(#<loc:push>#<loc:"foo.cr",2,25> end #<loc:pop>),
      %(__str__ << "\\n"),
      %(#<loc:push>#<loc:"foo.cr",3,3> # skip #<loc:pop>),
      %(__str__ << " "),
      %(__str__ << "<% \\"string\\" %>"),
    ]
    program.should eq(pieces.join('\n') + '\n')
  end

  it "does ECR.def_to_s" do
    view = ECRSpecHelloView.new("world!")
    view.to_s.strip.should eq("Hello world! 012")
  end

  it "does with <%= -%>" do
    io = IO::Memory.new
    ECR.embed "#{__DIR__}/../data/test_template2.ecr", io
    io.to_s.should eq("123")
  end

  it "does with <%- %> (1)" do
    io = IO::Memory.new
    ECR.embed "#{__DIR__}/../data/test_template3.ecr", io
    io.to_s.should eq("01")
  end

  it "does with <%- %> (2)" do
    io = IO::Memory.new
    ECR.embed "#{__DIR__}/../data/test_template4.ecr", io
    io.to_s.should eq("hi\n01")
  end

  it "does with <% -%>" do
    io = IO::Memory.new
    ECR.embed "#{__DIR__}/../data/test_template5.ecr", io
    io.to_s.should eq("hi\n      0\n      1\n  ")
  end

  it "does with -% inside string" do
    io = IO::Memory.new
    ECR.embed "#{__DIR__}/../data/test_template6.ecr", io
    io.to_s.should eq("string with -%")
  end

  it ".render" do
    ECR.render("#{__DIR__}/../data/test_template2.ecr").should eq("123")
  end
end

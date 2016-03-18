require "spec"
require "ecr"
require "ecr/macros"

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
      %((#<loc:"foo.cr",1,10> 1 ).to_s __str__),
      %(__str__ << " wor\\nld "),
      %(#<loc:"foo.cr",2,6> while true ),
      %(__str__ << " 2 "),
      %(#<loc:"foo.cr",2,25> end ),
      %(__str__ << "\\n"),
      %(#<loc:\"foo.cr\",3,3> # skip ),
      %(__str__ << " "),
      %(__str__ << "<% \\"string\\" %>"),
    ]
    program.should eq(pieces.join("\n") + "\n")
  end

  it "does ECR.def_to_s" do
    view = ECRSpecHelloView.new("world!")
    view.to_s.strip.should eq("Hello world! 012")
  end
end

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
    view.to_s.should eq("Hello world! 012\n")
  end

  it "skips newlines" do
    program = ECR.process_string "<% [1, 2].each do |num| -%>
  <%= num %>
<% end -%>", "foo.cr"
    result = "#<loc:\"foo.cr\",1,3> [1, 2].each do |num| \n__str__ << \"  \"\n(#<loc:\"foo.cr\",2,5> num ).to_s __str__\n__str__ << \"\\n\"\n#<loc:\"foo.cr\",3,3> end \n"
    program.should eq(result)
  end

end

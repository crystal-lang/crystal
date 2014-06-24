#!/usr/bin/env bin/crystal --run
require "spec"
require "ecr"

describe "ECR" do
  it "builds a crystal program from a source" do
    program = ECR.process_string "hello <%= 1 %> wor\nld <% while true %> 2 <% end %>", "foo.cr"

    pieces = [
      %(String.build do |__str__|),
      %(__str__ << "hello ")
      %(__str__ << #<loc:"foo.cr",1,10> 1 )
      %(__str__ << " wor\\nld "),
      %(#<loc:"foo.cr",2,6> while true ),
        %(__str__ << " 2 "),
      %(#<loc:"foo.cr",2,25> end ),
      %(end),
    ]
    program.should eq(pieces.join "\n")
  end
end

#!/usr/bin/env bin/crystal --run
require "spec"
require "ecr"

describe "ECR" do
  it "builds a crystal program from a source" do
    program = ECR.process_ecr "hello <%= 1 %> world <% while true %> 2 <% end %>"

    pieces = [
      %(String.build do |__str__|),
      %(__str__ << "hello ")
      %(__str__ <<  1 )
      %(__str__ << " world "),
      %( while true ),
        %(__str__ << " 2 "),
      %( end ),
      %(end),
    ]
    program.should eq(pieces.join "\n")
  end
end

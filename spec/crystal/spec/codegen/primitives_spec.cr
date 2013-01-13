require "spec"
require "../../spec_helper"
require "../../../../bootstrap/crystal/parser"
require "../../../../bootstrap/crystal/type_inference"
require "../../../../bootstrap/crystal/codegen"

include Crystal

describe "Code gen: primitives" do
  it "codegens bool" do
    run("true").to_b.should be_true
    run("false").to_b.should be_false
  end

  it "codegens int" do
    run("1").to_i.should eq(1)
  end
end
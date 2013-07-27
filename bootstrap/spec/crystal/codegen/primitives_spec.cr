require "spec"
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

  it "codegens long" do
    run("1L").to_i.should eq(1)
  end

  it "codegens char" do
    run("'a'").to_i.should eq('a'.ord)
  end

  it "codegens float" do
    run("1; 2.5f").to_f.should eq(2.5_f32)
  end

  it "codegens double" do
    run("1; 2.5").to_d.should eq(2.5)
  end
end
require 'spec_helper'

describe 'Type inference: const' do
  it "types a constant" do
    input = parse "A = 1"
    mod = infer_type input
    input.target.type.should eq(mod.int)
  end

  it "types a constant reference" do
    assert_type("A = 1; A") { int }
  end

  it "types a nested constant" do
    assert_type("class B; A = 1; end; B::A") { int }
  end
end

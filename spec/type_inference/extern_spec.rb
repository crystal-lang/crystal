require 'spec_helper'

describe 'Type inference: extern' do
  it "types extern call" do
    assert_type("extern foo : Int; foo") { int }
  end

  it "types extern call with arguments" do
    assert_type("extern foo(a : Int) : Float; foo(1)") { float }
  end
end

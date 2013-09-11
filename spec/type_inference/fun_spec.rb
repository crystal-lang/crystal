require 'spec_helper'

describe 'Type inference: fun' do
  it "types empty fun literal" do
    assert_type("-> {}") { fun_of(self.nil) }
  end

  it "types int fun literal" do
    assert_type("-> { 1 }") { fun_of(int32) }
  end

  it "types fun call" do
    assert_type("x = -> { 1 }; x.call()") { int32 }
  end
end

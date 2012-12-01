require 'spec_helper'

describe 'Type inference: pointer' do
  it "types int pointer" do
    assert_type('a = 1; ptr(a)') { PointerType.of(int) }
  end

  it "types pointer value" do
    assert_type('a = 1; b = ptr(a); b.value') { int }
  end
end
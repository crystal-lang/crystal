require 'spec_helper'

describe 'Type inference: pointer' do
  it "types int pointer" do
    assert_type('a = 1; ptr(a)') { PointerType.of(int) }
  end
end
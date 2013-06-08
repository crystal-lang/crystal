require 'spec_helper'

describe 'Type inference: while' do
  it "types while" do
    assert_type('while 1; 1; end') { self.nil }
  end

  it "types while with break without value" do
    assert_type('while true; break; end') { self.nil }
  end

  it "types while with break with value" do
    assert_type('while true; break 1; end') { union_of(self.nil, int) }
  end

  it "reports break cannot be used outside a while" do
    assert_error 'break',
      "Invalid break"
  end

  it "types while true as NoReturn" do
    assert_type('while true; end') { no_return }
  end
end
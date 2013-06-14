require 'spec_helper'

describe 'Type inference: enum' do
  it "types enum value" do
    mod, type = assert_type("lib Foo; enum Bar; X, Y, Z = 10, W; end end Foo::Bar::X") { int32 }
  end
end
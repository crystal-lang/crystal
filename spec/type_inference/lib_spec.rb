require 'spec_helper'

describe 'Type inference: lib' do
  it "types a varargs external" do
    assert_type("lib Foo; fun bar(x : Int, ...) : Int; end; Foo.bar(1, 1.5, 'a')") { int }
  end
end

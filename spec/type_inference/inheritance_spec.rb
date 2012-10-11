require 'spec_helper'

describe 'Type inference: inheritance' do
  it "calls method from object" do
    assert_type("class Object; def foo; 1; end; end; class Foo; end; Foo.new.foo") { int }
  end

  it "calls method from parent" do
    assert_type("class Foo; def foo; 1; end; end; class Bar < Foo; end; Bar.new.foo") { int }
  end
end

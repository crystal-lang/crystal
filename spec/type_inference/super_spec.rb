require 'spec_helper'

describe 'Type inference: super' do
  it "types super without arguments" do
    assert_type("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { int }
  end

  it "codegens super without arguments and instance variable" do
    assert_type("class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; bar = Bar.new; bar.foo; bar") { ObjectType.new('Bar').with_var('@x', int) }
  end

  it "types super without arguments but parent has arguments" do
    assert_type("class Foo; def foo(x); x; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)") { int }
  end
end

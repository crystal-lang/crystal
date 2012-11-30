require 'spec_helper'

describe 'Codegen: super' do
  it "codegens super without arguments" do
    run("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { 1 }
  end

  it "codegens super without arguments but parent has arguments" do
    run("class Foo; def foo(x); x + 1; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)") { 2 }
  end
end

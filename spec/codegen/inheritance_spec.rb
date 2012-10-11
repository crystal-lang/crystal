require 'spec_helper'

describe 'Codegen: inheritance' do
  it "calls method from object" do
    run("class Object; def foo; 1; end; end; class Foo; end; Foo.new.foo").to_i.should eq(1)
  end

  it "calls method from parent" do
    run("class Foo; def foo; 1; end; end; class Bar < Foo; end; Bar.new.foo").to_i.should eq(1)
  end
end

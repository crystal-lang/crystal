require 'spec_helper'

describe 'Type inference: primitives' do
  it "types a bool" do
    input = false.bool
    type input
    input.type.should eq(Type::Bool)
  end

  it "types an int" do
    input = 1.int
    type input
    input.type.should eq(Type::Int)
  end

  it "types a float" do
    input = 2.3.float
    type input
    input.type.should eq(Type::Float)
  end

  it "types a primitive method" do
    input = parse 'class Int; def foo; 2.5; end; end; 1.foo'
    type input
    input.last.type.should eq(Type::Float)
  end
end
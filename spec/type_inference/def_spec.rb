require 'spec_helper'

describe 'Type inference: def' do
  it "types a call with an int" do
    input = parse 'def foo; 1; end; foo'
    type input
    input.last.type.should eq(Type::Int)
  end

  it "types a call with a float" do
    input = parse 'def foo; 2.3; end; foo'
    type input
    input.last.type.should eq(Type::Float)
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1'
    type input
    input.last.type.should eq(Type::Int)
  end

  it "types a call with an argument uses a new scope" do
    input = parse 'x = 2.3; def foo(x); x; end; foo 1; x'
    type input
    input.last.type.should eq(Type::Float)
  end
end

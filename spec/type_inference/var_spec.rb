require 'spec_helper'

describe 'Type inference: var' do
  it "types an assign" do
    input = Assign.new('a'.var, 1.int)
    type input
    input.target.type.should eq(Type::Int)
    input.value.type.should eq(Type::Int)
    input.type.should eq(Type::Int)
  end

  it "types a variable" do
    input = parse 'a = 1; a'
    type input

    input.last.type.should eq(Type::Int)
    input.type.should eq(Type::Int)
  end

  it "types a variable that gets a new type" do
    input = parse 'a = 1; a; a = 2.3; a'
    type input

    input[1].type.should eq(Type::Int)
    input[2].type.should eq(Type::Float)
    input[3].type.should eq(Type::Float)
  end
end
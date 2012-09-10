require 'spec_helper'

describe 'Type inference' do
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

  it "types an assignment" do
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
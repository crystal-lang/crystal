require 'spec_helper'

describe 'Type inference: primitives' do
  it "types a bool" do
    input = false.bool
    mod = type input
    input.type.should eq(mod.bool)
  end

  it "types an int" do
    input = 1.int
    mod = type input
    input.type.should eq(mod.int)
  end

  it "types a float" do
    input = 2.3.float
    mod = type input
    input.type.should eq(mod.float)
  end

  it "types a char" do
    input = Char.new(?a.ord)
    mod = type input
    input.type.should eq(mod.char)
  end

  it "types a primitive method" do
    input = parse 'class Int; def foo; 2.5; end; end; 1.foo'
    mod = type input
    input.last.type.should eq(mod.float)
  end

  ['+', '-', '*', '/'].each do |op|
    it "types Int #{op} Int" do
      input = parse "1 #{op} 2"
      mod = type input
      input.type.should eq(mod.int)
    end

    it "types Int #{op} Float" do
      input = parse "1 #{op} 2.0"
      mod = type input
      input.type.should eq(mod.float)
    end

    it "types Float #{op} Int" do
      input = parse "1.0 #{op} 2"
      mod = type input
      input.type.should eq(mod.float)
    end

    it "types Float #{op} Float" do
      input = parse "1.0 #{op} 2.0"
      mod = type input
      input.type.should eq(mod.float)
    end
  end

  ['==', '>', '>=', '<', '<=', '!='].each do |op|
    it "types Int #{op} Int" do
      input = parse "1 #{op} 2"
      mod = type input
      input.type.should eq(mod.bool)
    end

    it "types Int #{op} Float" do
      input = parse "1 #{op} 2.0"
      mod = type input
      input.type.should eq(mod.bool)
    end

    it "types Float #{op} Int" do
      input = parse "1.0 #{op} 2"
      mod = type input
      input.type.should eq(mod.bool)
    end

    it "types Float #{op} Float" do
      input = parse "1.0 #{op} 2.0"
      mod = type input
      input.type.should eq(mod.bool)
    end
  end

end
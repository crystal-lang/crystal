require 'spec_helper'

describe 'Type inference: if' do
  it "types an if without else" do
    input = parse 'if true; 1; end'
    mod = type input
    input.last.type.should eq(mod.int)
  end

  it "types an if with else of same type" do
    input = parse 'if true; 1; else; 2; end'
    mod = type input
    input.last.type.should eq(mod.int)
  end

  it "types an if with else of different type" do
    input = parse 'if true; 1; else; 1.1; end'
    mod = type input
    input.last.type.should eq([mod.int, mod.float])
  end

end
require 'spec_helper'

describe 'Type inference: def' do
  it "types a call with an int" do
    input = parse 'def foo; 1; end; foo'
    mod = type input
    input.last.type.should eq(mod.int)
  end

  it "types a call with a float" do
    input = parse 'def foo; 2.3; end; foo'
    mod = type input
    input.last.type.should eq(mod.float)
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1; foo 2.3'
    mod = type input
    input[1].type.should eq(mod.int)
    input[2].type.should eq(mod.float)
  end

  it "types a call with an argument uses a new scope" do
    input = parse 'x = 2.3; def foo(x); x; end; foo 1; x'
    mod = type input
    input.last.type.should eq(mod.float)
  end

  it "assigns def owner" do
    input = parse 'class Int; def foo; 2.5; end; end; 1.foo'
    mod = type input
    input.last.target_def.owner.should eq(mod.int)
  end

  it "reuses def instance" do
    input = parse 'def foo; 1; end; foo; foo'
    type input
    input[1].target_def.should equal(input[2].target_def)
  end

  it "types putchar with Char" do
    input = parse "putchar 'a'"
    mod = type input
    input.last.type.should eq(mod.char)
  end
end

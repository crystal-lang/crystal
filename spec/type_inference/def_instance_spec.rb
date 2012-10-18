require 'spec_helper'

describe 'Type inference: def instance' do

  it "types a call with an int" do
    input = parse 'def foo; 1; end; foo'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call with a primitive argument" do
    input = parse 'def foo(x); x; end; foo 1'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call with an object type argument" do
    input = parse 'def foo(x); x; end; foo Object.new'
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "types a call returning new type" do
    input = parse 'def foo; Object.new; end; foo'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.object)
  end

  test_type = "class Foo; #{rw :value}; end"

  it "types a call not returning path of argument with primitive type" do
    input = parse "#{test_type}; def foo(x); x.value; end; f = Foo.new; f.value = 1; foo(f)"
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call returning path of self" do
    input = parse "#{test_type}; f = Foo.new; f.value = Object.new; f.value"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of argument" do
    input = parse "#{test_type}; def foo(x); x.value; end; f = Foo.new; f.value = Object.new; foo(f)"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of second argument" do
    input = parse "#{test_type}; def foo(y, x); x.value; end; f = Foo.new; f.value = Object.new; foo(0, f)"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(1, '@value'))
  end

end
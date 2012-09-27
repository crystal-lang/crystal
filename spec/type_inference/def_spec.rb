require 'spec_helper'

describe 'Type inference: def' do
  it "types a call with an int" do
    assert_type('def foo; 1; end; foo') { int }
  end

  it "types a call with a float" do
    assert_type('def foo; 2.3; end; foo') { float }
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1'
    mod = infer_type input
    input.last.type.should eq(mod.int)
  end

  it "types a call with an argument" do
    input = parse 'def foo(x); x; end; foo 1; foo 2.3'
    mod = infer_type input
    input[1].type.should eq(mod.int)
    input[2].type.should eq(mod.float)
  end

  it "types a call with an argument uses a new scope" do
    assert_type('x = 2.3; def foo(x); x; end; foo 1; x') { float }
  end

  it "assigns def owner" do
    input = parse 'class Int; def foo; 2.5; end; end; 1.foo'
    mod = infer_type input
    input.last.target_def.owner.should eq(mod.int)
  end

  it "reuses def instance" do
    input = parse 'def foo; 1; end; foo; foo'
    infer_type input
    input[1].target_def.should equal(input[2].target_def)
  end

  it "types putchar with Char" do
    assert_type("putchar 'a'") { char }
  end

  it "types getchar with Char" do
    assert_type("getchar") { char }
  end

  it "allows recursion" do
    input = parse "def foo; foo; end; foo"
    infer_type input
  end

  it "allows recursion with arg" do
    input = parse "def foo(x); foo(x); end; foo 1"
    infer_type input
  end

  it "types recursion" do
    input = parse 'def foo(x); if x > 0; foo(x - 1) + 1; else; 1; end; end; foo(5)'
    mod = infer_type input
    input.last.type.should eq(mod.int)
    input.last.target_def.body.first.then.type.should eq(mod.int)
  end

  it "types recursion 2" do
    input = parse 'def foo(x); if x > 0; 1 + foo(x - 1); else; 1; end; end; foo(5)'
    mod = infer_type input
    input.last.type.should eq(mod.int)
    input.last.target_def.body.first.then.type.should eq(mod.int)
  end

  it "types mutual recursion" do
    input = parse 'def foo(x); if true; bar(x); else; 1; end; end; def bar(x); foo(x); end; foo(5)'
    mod = infer_type input
    input.last.type.should eq(mod.int)
    input.last.target_def.body.first.then.type.should eq(mod.int)
  end

  it "types empty body def" do
    assert_type('def foo; end; foo') { void }
  end
end

require 'spec_helper'

describe 'Type inference: class' do
  it "types lib" do
    input = parse "lib Foo; fun bar : Int; end; Foo"
    mod = infer_type input
    mod.types['Foo'].should eq(LibType.new('Foo'))
    input.last.type.should eq(mod.types['Foo'])
  end

  it "types pointer type" do
    input = parse "lib Foo; fun bar(a : Int*); end"
    mod = infer_type input
    mod.types['Foo'].lookup_def('bar').args.first.type.should eq(PointerType.of(mod.int))
  end

  it "types lib fun without args" do
    assert_type("lib Foo; fun bar : Int; end; Foo.bar") { int }
  end

  it "types lib fun with args" do
    assert_type("lib Foo; fun bar(a : Int) : Int; end; Foo.bar(1)") { int }
  end
end

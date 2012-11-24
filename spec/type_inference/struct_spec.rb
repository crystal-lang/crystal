require 'spec_helper'

describe 'Type inference: struct' do
  it "types struct" do
    input = parse "lib Foo; struct Bar; x : Int; y : Float; end; end; Foo::Bar"
    mod = infer_type input
    mod.types['Foo'].types['Bar'].should eq(StructType.new('Bar', [Var.new('x', mod.int), Var.new('y', mod.float)]))
    input.last.type.should eq(mod.types['Foo'].types['Bar'].metaclass)
  end

  it "types Struct#new" do
    assert_type("lib Foo; struct Bar; x : Int; y : Float; end; end; Foo::Bar.new") { StructType.new('Bar', [Var.new('x', int), Var.new('y', float)]) }
  end

  it "types struct setter" do
    assert_type("lib Foo; struct Bar; x : Int; y : Float; end; end; bar = Foo::Bar.new; bar.x = 1") { int }
  end

  it "types struct getter" do
    assert_type("lib Foo; struct Bar; x : Int; y : Float; end; end; bar = Foo::Bar.new; bar.x") { int }
  end
end

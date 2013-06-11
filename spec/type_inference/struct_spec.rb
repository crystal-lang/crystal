require 'spec_helper'

describe 'Type inference: struct' do
  it "types struct" do
    mod, type = assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; Foo::Bar") { types['Foo'].types['Bar'].metaclass }
    mod.types['Foo'].types['Bar'].should be_struct
    mod.types['Foo'].types['Bar'].vars['x'].type.should eq(mod.int32)
    mod.types['Foo'].types['Bar'].vars['y'].type.should eq(mod.float64)
  end

  it "types Struct#new" do
    mod, type = assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; Foo::Bar.new") do
      types['Foo'].types['Bar']
    end
  end

  it "types struct setter" do
    assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; bar = Foo::Bar.new; bar.x = 1") { int32 }
  end

  it "types struct getter" do
    assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; bar = Foo::Bar.new; bar.x") { int32 }
  end

  it "types struct getter with keyword name" do
    assert_type("lib Foo; struct Bar; type : Int32; end; end; bar = Foo::Bar.new; bar.type") { int32 }
  end

  it "errors on struct if no field" do
    assert_error "lib Foo; struct Bar; x : Int32; end; end; Foo::Bar.new.y = 'a'",
      "struct Foo::Bar has no field 'y'"
  end

  it "errors on struct setter if different type" do
    assert_error "lib Foo; struct Bar; x : Int32; end; end; Foo::Bar.new.x = 'a'",
      "field 'x' of struct Foo::Bar has type Int32, not Char"
  end
end

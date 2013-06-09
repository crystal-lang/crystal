require 'spec_helper'

describe 'Type inference: struct' do
  it "types struct" do
    mod, type = assert_type("lib Foo; struct Bar; x : Int; y : Float; end; end; Foo::Bar") { types['Foo'].types['Bar'].metaclass }
    mod.types['Foo'].types['Bar'].should be_struct
    mod.types['Foo'].types['Bar'].vars['x'].type.should eq(mod.int)
    mod.types['Foo'].types['Bar'].vars['y'].type.should eq(mod.float)
  end

  it "types Struct#new" do
    mod, type = assert_type("lib Foo; struct Bar; x : Int; y : Float; end; end; Foo::Bar.new") do
      types['Foo'].types['Bar']
    end
  end

  it "types struct setter" do
    assert_type("lib Foo; struct Bar; x : Int; y : Float; end; end; bar = Foo::Bar.new; bar.x = 1") { int }
  end

  it "types struct getter" do
    assert_type("lib Foo; struct Bar; x : Int; y : Float; end; end; bar = Foo::Bar.new; bar.x") { int }
  end

  it "types struct getter with keyword name" do
    assert_type("lib Foo; struct Bar; type : Int; end; end; bar = Foo::Bar.new; bar.type") { int }
  end
end

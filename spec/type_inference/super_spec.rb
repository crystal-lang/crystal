require 'spec_helper'

describe 'Type inference: super' do
  it "types super without arguments" do
    assert_type("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { int }
  end

  it "types super without arguments and instance variable" do
    mod, type = assert_type("class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; bar = Bar.new; bar.foo; bar") do
      types["Bar"]
    end
    type.superclass.instance_vars['@x'].type.should eq(mod.union_of(mod.nil, mod.int))
  end

  it "types super without arguments but parent has arguments" do
    assert_type("class Foo; def foo(x); x; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)") { int }
  end

  it "types super when container method is defined in parent class" do
    nodes = parse %(
      class Foo
        def initialize
          @x = 1
        end
      end
      class Bar < Foo
        def initialize
          super
        end
      end
      class Baz < Bar
      end
      Baz.new
      )
    mod = infer_type nodes
    nodes.last.type.should eq(mod.types["Baz"])
    nodes.last.type.superclass.superclass.instance_vars["@x"].type.should eq(mod.int)
  end
end

require 'spec_helper'

describe 'Type inference: super' do
  it "types super without arguments" do
    assert_type("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { int }
  end

  it "codegens super without arguments and instance variable" do
    input = parse "class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; bar = Bar.new; bar.foo; bar"
    mod = infer_type input
    mod.types["Bar"].lookup_instance_var("@x").type.should eq(mod.int)
  end

  it "types super without arguments but parent has arguments" do
    assert_type("class Foo; def foo(x); x; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)") { int }
  end

  it "types super when container method is defined in parent class" do
    input = parse(%Q(
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
      ))
    mod = infer_type input
    mod.types["Baz"].lookup_instance_var("@x").type.should eq(mod.int)
  end
end

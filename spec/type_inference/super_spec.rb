require 'spec_helper'

describe 'Type inference: super' do
  it "types super without arguments" do
    assert_type("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo") { int }
  end

  it "types super without arguments and instance variable" do
    assert_type("class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; bar = Bar.new; bar.foo; bar") do
      "Bar".object(x: union_of(self.nil, int))
    end
  end

  it "types super without arguments but parent has arguments" do
    assert_type("class Foo; def foo(x); x; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)") { int }
  end

  it "types super when container method is defined in parent class" do
    assert_type(%(
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
      )) { "Baz".object(x: int) }
  end
end

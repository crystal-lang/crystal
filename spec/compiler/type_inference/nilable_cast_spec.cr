require "../../spec_helper"

describe "Type inference: nilable cast" do
  it "types as?" do
    assert_type(%(
      1.as?(Float64)
      )) { nilable float64 }
  end

  it "types as? with nil" do
    assert_type(%(
      1.as?(Nil)
      )) { |mod| mod.nil }
  end

  it "does upcast" do
    assert_type(%(
      class Foo
        def bar
          1
        end
      end

      class Bar < Foo
        def bar
          2
        end
      end

      Bar.new.as?(Foo)
      )) { nilable types["Foo"].virtual_type! }
  end
end

require "../../spec_helper"

describe "Semantic: nilable cast" do
  it "types as?" do
    assert_type(%(
      1.as?(Float64)
      )) { nilable float64 }
  end

  it "types as? with union" do
    assert_type(%(
      (1 || 'a').as?(Int32)
      )) { nilable int32 }
  end

  it "types as? with nil" do
    assert_type(%(
      1.as?(Nil)
      )) { nil_type }
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

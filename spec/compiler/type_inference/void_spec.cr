require "../../spec_helper"

describe "Type inference: void" do
  it "merges void with other types" do
    assert_type(%(
      lib LibFoo
        fun foo
      end

      a = LibFoo.foo
      b = 1
      c = 'a'
      b || c || a
      )) { void }
  end

  it "marks method as void when using it as return type" do
    assert_type(%(
      def foo : Void
        1
      end

      foo
      )) { void }
  end
end

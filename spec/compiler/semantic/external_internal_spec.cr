require "../../spec_helper"

describe "Semantic: external/internal" do
  it "can call with external name and use with internal" do
    assert_type(%(
      def foo(x y)
        y
      end

      foo x: 10
      )) { int32 }
  end

  it "can call positionally" do
    assert_type(%(
      def foo(x y)
        y
      end

      foo 10
      )) { int32 }
  end

  it "can call with external name and use with internal, after splat" do
    assert_type(%(
      def foo(*, x y)
        y
      end

      foo x: 10
      )) { int32 }
  end

  it "overloads based on external name (#2610)" do
    assert_type(%(
      def foo(*, bar foo)
        1
      end

      def foo(*, baz foo)
        2
      end

      foo(bar: 1) + foo(baz: 1)
      ), inject_primitives: true) { int32 }
  end

  context "macros" do
    it "can call with external name and use with internal" do
      assert_type(%(
        macro foo(x y)
          {{y}}
        end

        foo x: 10
        )) { int32 }
    end

    it "can call positionally" do
      assert_type(%(
        macro foo(x y)
          {{y}}
        end

        foo 10
        )) { int32 }
    end

    it "can call with external name and use with internal, after splat" do
      assert_type(%(
        macro foo(*, x y)
          {{y}}
        end

        foo x: 10
        )) { int32 }
    end
  end
end

require "../../spec_helper"

describe "Type inference: external/internal" do
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

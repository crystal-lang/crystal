require "../../spec_helper"

describe "Semantic: external/internal" do
  it "can call with external name and use with internal" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo(x y)
        y
      end

      foo x: 10
      CRYSTAL
  end

  it "can call positionally" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo(x y)
        y
      end

      foo 10
      CRYSTAL
  end

  it "can call with external name and use with internal, after splat" do
    assert_type(<<-CRYSTAL) { int32 }
      def foo(*, x y)
        y
      end

      foo x: 10
      CRYSTAL
  end

  it "overloads based on external name (#2610)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      def foo(*, bar foo)
        1
      end

      def foo(*, baz foo)
        2
      end

      foo(bar: 1) + foo(baz: 1)
      CRYSTAL
  end

  context "macros" do
    it "can call with external name and use with internal" do
      assert_type(<<-CRYSTAL) { int32 }
        macro foo(x y)
          {{y}}
        end

        foo x: 10
        CRYSTAL
    end

    it "can call positionally" do
      assert_type(<<-CRYSTAL) { int32 }
        macro foo(x y)
          {{y}}
        end

        foo 10
        CRYSTAL
    end

    it "can call with external name and use with internal, after splat" do
      assert_type(<<-CRYSTAL) { int32 }
        macro foo(*, x y)
          {{y}}
        end

        foo x: 10
        CRYSTAL
    end
  end
end

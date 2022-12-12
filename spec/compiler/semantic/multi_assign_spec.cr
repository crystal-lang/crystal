require "../../spec_helper"

describe "Semantic: multi assign" do
  context "without strict_multi_assign" do
    it "doesn't error if assigning tuple to fewer targets" do
      assert_type(%(
        require "prelude"

        x = {1, 2, ""}
        a, b = x
        {a, b}
        )) { tuple_of [int32, int32] }
    end

    it "doesn't error if assigning non-Indexable (#11414)" do
      assert_no_errors <<-CRYSTAL
        class Foo
          def [](index)
          end

          def size
            3
          end
        end

        a, b, c = Foo.new
        CRYSTAL
    end

    it "errors if assigning non-Indexable to splat (#11414)" do
      assert_error <<-CRYSTAL, "right-hand side of one-to-many assignment must be an Indexable, not Foo"
        require "prelude"

        class Foo
          def [](index)
          end

          def size
            3
          end
        end

        a, *b, c = Foo.new
        CRYSTAL
    end
  end

  context "strict_multi_assign" do
    it "errors if assigning tuple to fewer targets" do
      assert_error %(
        require "prelude"

        x = {1, 2, ""}
        a, b = x
        ), "cannot assign Tuple(Int32, Int32, String) to 2 targets", flags: "strict_multi_assign"
    end

    pending "errors if assigning tuple to more targets" do
      assert_error %(
        require "prelude"

        x = {1}
        a, b = x
        ), "cannot assign Tuple(Int32) to 2 targets", flags: "strict_multi_assign"
    end

    it "errors if assigning union of tuples to fewer targets" do
      assert_error %(
        require "prelude"

        x = true ? {1, 2, 3} : {4, 5, 6, 7}
        a, b = x
        ), "cannot assign (Tuple(Int32, Int32, Int32) | Tuple(Int32, Int32, Int32, Int32)) to 2 targets", flags: "strict_multi_assign"
    end

    it "doesn't error if some type in union matches target count" do
      assert_type(%(
        require "prelude"

        x = true ? {1, "", 3} : {4, 5}
        a, b = x
        {a, b}
        ), flags: "strict_multi_assign") { tuple_of [int32, union_of(int32, string)] }
    end

    it "doesn't error if some type in union has no constant size" do
      assert_type(%(
        require "prelude"

        x = true ? {1, "", 3} : [4, 5]
        a, b = x
        {a, b}
        ), flags: "strict_multi_assign") { tuple_of [int32, union_of(int32, string)] }
    end

    it "errors if assigning non-Indexable (#11414)" do
      assert_error <<-CRYSTAL, "right-hand side of one-to-many assignment must be an Indexable, not Foo", flags: "strict_multi_assign"
        require "prelude"

        class Foo
          def [](index)
          end

          def size
            3
          end
        end

        a, b, c = Foo.new
        CRYSTAL
    end

    it "errors if assigning non-Indexable to splat (#11414)" do
      assert_error <<-CRYSTAL, "right-hand side of one-to-many assignment must be an Indexable, not Foo", flags: "strict_multi_assign"
        require "prelude"

        class Foo
          def [](index)
          end

          def size
            3
          end
        end

        a, *b, c = Foo.new
        CRYSTAL
    end
  end

  it "can pass splat variable at top-level to macros (#11596)" do
    assert_type(<<-CRYSTAL) { tuple_of [int32, int32, int32] }
      struct Tuple
        def self.new(*args)
          args
        end
      end

      macro foo(x)
        {{ x }}
      end

      a, *b, c = 1, 2, 3, 4, 5
      foo(b)
      CRYSTAL
  end
end

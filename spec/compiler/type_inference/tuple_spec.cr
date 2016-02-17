require "../../spec_helper"

describe "Type inference: tuples" do
  it "types tuple of one element" do
    assert_type("{1}") { tuple_of([int32] of TypeVar) }
  end

  it "types tuple of three elements" do
    assert_type("{1, 2.5, 'a'}") { tuple_of([int32, float64, char] of TypeVar) }
  end

  it "types tuple of one element and then two elements" do
    assert_type("{1}; {1, 2}") { tuple_of([int32, int32] of TypeVar) }
  end

  it "types tuple [0]" do
    assert_type("{1, 'a'}[0]") { int32 }
  end

  it "types tuple [1]" do
    assert_type("{1, 'a'}[1]") { char }
  end

  it "types tuple metaclass [0]" do
    assert_type("{1, 'a'}.class[0]") { int32.metaclass }
  end

  it "types tuple metaclass [1]" do
    assert_type("{1, 'a'}.class[1]") { char.metaclass }
  end

  it "gives error when indexing out of range" do
    assert_error "{1, 'a'}[2]",
      "index out of bounds for tuple {Int32, Char}"
  end

  it "can name a tuple type" do
    assert_type("Tuple(Int32, Float64)") { tuple_of([int32, float64]).metaclass }
  end

  it "types T as a tuple of metalcasses" do
    assert_type("
      struct Tuple
        def types
          T
        end
      end

      x = {1, 1.5, 'a'}
      x.types
      ") do
      meta = tuple_of([int32, float64, char]).metaclass
      meta.metaclass?.should be_true
      meta
    end
  end

  it "errors on recursive splat expansion (#218)" do
    assert_error %(
      def foo(*a)
        foo(a)
      end

      def foo(a : Tuple(String))
      end

      foo("a", "b")
      ),
      "recursive splat expansion"
  end

  it "errors on recusrive splat expansion (1) (#361)" do
    assert_error %(
      require "prelude"

      def foo(type, *args)
        foo 1, args.to_a
      end

      foo "foo", 1
      ),
      "recursive splat expansion"
  end

  it "errors on recursive splat expansion (2) (#361)" do
    assert_error %(
      class Foo(T)
      end

      def foo(type, *args)
        foo 1, Foo(typeof(args)).new
      end

      foo "foo", 1
      ),
      "recursive splat expansion"
  end
end

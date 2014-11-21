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

  it "gives error when indexing out of range" do
    assert_error "{1, 'a'}[2]",
      "index out of bounds for tuple {Int32, Char}"
  end

  it "can name a tuple type" do
    assert_type("Tuple(Int32, Float64)") { tuple_of([int32, float64]).metaclass }
  end

  it "types T as a tuple of metalcasses" do
    assert_type("
      class Tuple
        def types
          T
        end
      end

      x = {1, 1.5, 'a'}
      x.types
      ") { tuple_of [int32.metaclass, float64.metaclass, char.metaclass] }
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
end

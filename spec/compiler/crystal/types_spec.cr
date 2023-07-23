require "../../spec_helper"

private def assert_type_to_s(expected, &)
  p = Program.new
  t = with p yield p
  t.to_s.should eq(expected)
end

describe "types to_s of" do
  it "does for type contained in generic class" do
    result = semantic(%(
      class Bar(T)
        class Foo
        end
      end
    ))
    result.program.types["Bar"].types["Foo"].to_s.should eq("Bar::Foo")
  end

  it "does for type contained in generic module" do
    result = semantic(%(
      module Bar(T)
        class Foo
        end
      end
    ))
    result.program.types["Bar"].types["Foo"].to_s.should eq("Bar::Foo")
  end

  it "non-instantiated array" do
    assert_type_to_s "Array(T)" { array }
  end

  it "array of simple types" do
    assert_type_to_s "Array(Int32)" { array_of(int32) }
  end

  it "union of simple types" do
    assert_type_to_s "(Int32 | String)" { union_of(string, int32) }
  end

  it "named tuple" do
    assert_type_to_s %(NamedTuple(a: Int32, "b c": String, "+": Char)) { named_tuple_of({"a" => int32, "b c" => string, "+" => char}) }
  end

  it "nilable reference type" do
    assert_type_to_s "(String | Nil)" { nilable string }
  end

  it "nilable value type" do
    assert_type_to_s "(Int32 | Nil)" { nilable int32 }
  end

  it "nilable type with more than two elements, Nil at the end" do
    assert_type_to_s "(Int32 | String | Nil)" { union_of(string, int32, nil_type) }
  end

  describe "union types" do
    describe "should not have extra parens" do
      it "in arrays" do
        assert_type_to_s "Array(Int32 | String)" { array_of(union_of(string, int32)) }
      end

      it "in pointers" do
        assert_type_to_s "Pointer(Int32 | String)" { pointer_of(union_of(string, int32)) }
      end

      it "in tuples" do
        assert_type_to_s "Tuple(String, Int32 | String)" { tuple_of [string, union_of(string, int32)] }
      end
    end

    describe "should have parens" do
      it "as return type" do
        assert_type_to_s "Proc((Int32 | String))" { proc_of union_of(string, int32) }
      end

      it "as arg type" do
        assert_type_to_s "Proc((Int32 | String), Int32)" { proc_of union_of(string, int32), int32 }
      end
    end
  end
end

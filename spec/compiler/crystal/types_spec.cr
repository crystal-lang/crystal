require "../../spec_helper"

def assert_type_to_s(expected)
  p = Program.new
  t = with p yield p
  t.to_s.should eq(expected)
end

describe "types to_s of" do
  it "does for type contained in generic class" do
    result = infer_type(%(
      class Bar(T)
        class Foo
        end
      end
    ))
    result.program.types["Bar"].types["Foo"].to_s.should eq("Bar::Foo")
  end

  it "does for type contained in generic module" do
    result = infer_type(%(
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

  it "nilable reference type" do
    assert_type_to_s "String?" { nilable string }
  end

  it "nilable value type" do
    assert_type_to_s "Int32?" { nilable int32 }
  end

  it "nilable type with more than two elements, Nil at the end" do
    assert_type_to_s "(Int32 | String | Nil)" { |mod| union_of(string, int32, mod.nil) }
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
        assert_type_to_s "{String, Int32 | String}" { tuple_of [string, union_of(string, int32)] }
      end
    end

    describe "should have parens" do
      it "as return type" do
        assert_type_to_s "( -> (Int32 | String))" { fun_of union_of(string, int32) }
      end

      it "as arg type" do
        assert_type_to_s "((Int32 | String) -> Int32)" { fun_of union_of(string, int32), int32 }
      end
    end
  end
end

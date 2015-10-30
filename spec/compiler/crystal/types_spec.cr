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

  it "array of simple types" do
    assert_type_to_s "(String | Int32)" { union_of(string, int32) }
  end

  describe "union types" do
    describe "should not have extra parens" do
      it "in arrays" do
        assert_type_to_s "Array(String | Int32)" { array_of(union_of(string, int32)) }
      end

      it "in pointers" do
        assert_type_to_s "Pointer(String | Int32)" { pointer_of(union_of(string, int32)) }
      end

      it "in tuples" do
        assert_type_to_s "{String, String | Int32}" { tuple_of [string, union_of(string, int32)] }
      end
    end

    describe "should have parens" do
      it "as return type" do
        assert_type_to_s "( -> (String | Int32))" { fun_of union_of(string, int32) }
      end

      it "as arg type" do
        assert_type_to_s "((String | Int32) -> Int32)" { fun_of union_of(string, int32), int32 }
      end
    end
  end
end

require "../../spec_helper"

def assert_type_to_s(expected)
  t = yield Program.new
  t.to_s.should eq(expected)
end

describe "types to_s of" do
  it "array of simple types" do
    assert_type_to_s "Array(Int32)" do |p|
      p.array_of(p.int32)
    end
  end

  it "array of simple types" do
    assert_type_to_s "(String | Int32)" do |p|
      p.union_of(p.string, p.int32)
    end
  end

  describe "union types" do
    describe "should not have extra parens" do
      it "in arrays" do
        assert_type_to_s "Array(String | Int32)" do |p|
          p.array_of(p.union_of(p.string, p.int32))
        end
      end

      it "in pointers" do
        assert_type_to_s "Pointer(String | Int32)" do |p|
          p.pointer_of(p.union_of(p.string, p.int32))
        end
      end

      it "in tuples" do
        assert_type_to_s "{String, String | Int32}" do |p|
          p.tuple_of([p.string, p.union_of(p.string, p.int32)])
        end
      end
    end

    describe "should have parens" do
      it "as return type" do
        assert_type_to_s "( -> (String | Int32))" do |p|
          p.fun_of([p.union_of(p.string, p.int32)])
        end
      end

      it "as arg type" do
        assert_type_to_s "((String | Int32) -> Int32)" do |p|
          p.fun_of([p.union_of(p.string, p.int32), p.int32])
        end
      end
    end
  end
end

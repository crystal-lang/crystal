require "../../spec_helper"

describe "Semantic: multi assign" do
  context "preview_multi_assign" do
    it "errors if assigning tuple to fewer targets" do
      assert_error %(
        require "prelude"

        x = {1, 2, ""}
        a, b = x
        ), "cannot assign Tuple(Int32, Int32, String) to 2 targets", flags: "preview_multi_assign"
    end

    pending "errors if assigning tuple to more targets" do
      assert_error %(
        require "prelude"

        x = {1}
        a, b = x
        ), "cannot assign Tuple(Int32) to 2 targets", flags: "preview_multi_assign"
    end

    it "errors if assigning union of tuples to fewer targets" do
      assert_error %(
        require "prelude"

        x = true ? {1, 2, 3} : {4, 5, 6, 7}
        a, b = x
        ), "cannot assign (Tuple(Int32, Int32, Int32) | Tuple(Int32, Int32, Int32, Int32)) to 2 targets", flags: "preview_multi_assign"
    end

    it "doesn't error if some type in union matches target count" do
      assert_type(%(
        require "prelude"

        x = true ? {1, "", 3} : {4, 5}
        a, b = x
        {a, b}
        ), flags: "preview_multi_assign") { tuple_of [int32, union_of(int32, string)] }
    end

    it "doesn't error if some type in union has no constant size" do
      assert_type(%(
        require "prelude"

        x = true ? {1, "", 3} : [4, 5]
        a, b = x
        {a, b}
        ), flags: "preview_multi_assign") { tuple_of [int32, union_of(int32, string)] }
    end
  end
end

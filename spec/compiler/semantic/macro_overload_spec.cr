require "../../spec_helper"

describe "Semantic: macro overload" do
  it "doesn't overwrite last macro definition if named args differs" do
    assert_type(<<-CRYSTAL) { int32 }
      macro foo(*, arg1)
        1
      end

      macro foo(*, arg2)
        "foo"
      end

      foo(arg1: true)
      CRYSTAL

    assert_type(<<-CRYSTAL) { string }
      macro foo(*, arg1)
        1
      end

      macro foo(*, arg2)
        "foo"
      end

      foo(arg2: true)
      CRYSTAL
  end
end

require "../../spec_helper"

describe "Semantic: macro overload" do
  it "doesn't overwrite last macro definition if named args differs" do
    assert_type(%(
      macro foo(*, arg1)
        1
      end

      macro foo(*, arg2)
        "foo"
      end

      foo(arg1: true)
    )) { int32 }

    assert_type(%(
      macro foo(*, arg1)
        1
      end

      macro foo(*, arg2)
        "foo"
      end

      foo(arg2: true)
    )) { string }
  end
end

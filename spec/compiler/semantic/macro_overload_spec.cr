require "../../spec_helper"

describe "Semantic: macro overload" do
  it "something between 2 macros (I need a name!!!)" do
    assert_type(%(
      macro foo(*, arg1)
        {{ arg1 }}
      end

      macro foo(*, arg2)
        {{ arg2 }}
      end

      foo(arg1: 1)
    )) { int32 }

    assert_type(%(
      macro foo(*, arg1)
        {{ arg1 }}
      end

      macro foo(*, arg2)
        {{ arg2 }}
      end

      foo(arg2: "test")
    )) { string }
  end
end

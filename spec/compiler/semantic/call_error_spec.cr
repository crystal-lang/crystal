require "../../spec_helper"

describe "Call errors" do
  it "says wrong number of arguments (to few arguments)" do
    assert_error %(
      def foo(x)
      end

      foo
      ),
      "wrong number of arguments for 'foo' (given 0, expected 1)"
  end
end

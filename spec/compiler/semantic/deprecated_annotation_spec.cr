require "../../spec_helper"

describe "Deprecated" do
  it "errors if invalid argument type" do
    assert_error %(
      @[Deprecated(42)]
      def foo
      end
      ),
      "Error in line 3: first argument must be a String"
  end

  it "errors if too many arguments" do
    assert_error %(
      @[Deprecated("Do not use me", "extra arg")]
      def foo
      end
      ),
      "Error in line 3: wrong number of deprecated annotation arguments (given 2, expected 1)"
  end

  it "errors if missing link arguments" do
    assert_error %(
      @[Deprecated(invalid: "Do not use me")]
      def foo
      end
      ),
      "Error in line 3: too many named arguments (given 1, expected maximum 0)"
  end
end

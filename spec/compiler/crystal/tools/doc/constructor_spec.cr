require "../../../spec_helper"

describe Crystal::ConstructorAnnotation do
  it "compiles with no argument" do
    assert_type(<<-CRYSTAL) { int32 }
      @[Constructor]
      def foo
      end

      2
      CRYSTAL
  end

  it "compiles with single boolean argument" do
    assert_type(<<-CRYSTAL) { int32 }
      @[Constructor(false)]
      def foo
      end

      2
      CRYSTAL
  end

  it "errors if invalid argument type" do
    assert_error %(
      @[Constructor(1)]
      def foo
      end
      ),
      "Error: first argument must be a Bool"
  end

  it "errors if too many arguments" do
    assert_error %(
      @[Constructor(false, "extra arg")]
      def foo
      end
      ),
      "Error: wrong number of constructor annotation arguments (given 2, expected 1)"
  end

  it "errors if given named arguments" do
    assert_error %(
      @[Constructor(invalid: "lorem ipsum")]
      def foo
      end
      ),
      "Error: too many named arguments (given 1, expected maximum 0)"
  end
end

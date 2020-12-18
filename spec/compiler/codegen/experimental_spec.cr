require "../spec_helper"

describe "Code gen: experimental" do
  it "compiles with no argument" do
    run(%(
      @[Experimental]
      def foo
      end

      2
      )).to_i.should eq(2)
  end

  it "compiles with single string argument" do
    run(%(
      @[Experimental("lorem ipsum")]
      def foo
      end

      2
      )).to_i.should eq(2)
  end

  it "errors if invalid argument type" do
    assert_error %(
      @[Experimental(42)]
      def foo
      end
      ),
      "first argument must be a String"
  end

  it "errors if too many arguments" do
    assert_error %(
      @[Experimental("lorem ipsum", "extra arg")]
      def foo
      end
      ),
      "wrong number of experimental annotation arguments (given 2, expected 1)"
  end

  it "errors if missing link arguments" do
    assert_error %(
      @[Experimental(invalid: "lorem ipsum")]
      def foo
      end
      ),
      "too many named arguments (given 1, expected maximum 0)"
  end
end

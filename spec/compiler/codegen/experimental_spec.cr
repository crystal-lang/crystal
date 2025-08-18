require "../spec_helper"

describe "Code gen: experimental" do
  it "compiles with no argument" do
    run(<<-CRYSTAL).to_i.should eq(2)
      @[Experimental]
      def foo
      end

      2
      CRYSTAL
  end

  it "compiles with single string argument" do
    run(<<-CRYSTAL).to_i.should eq(2)
      @[Experimental("lorem ipsum")]
      def foo
      end

      2
      CRYSTAL
  end

  it "errors if invalid argument type" do
    assert_error <<-CRYSTAL, "first argument must be a String"
      @[Experimental(42)]
      def foo
      end
      CRYSTAL
  end

  it "errors if too many arguments" do
    assert_error <<-CRYSTAL, "wrong number of experimental annotation arguments (given 2, expected 1)"
      @[Experimental("lorem ipsum", "extra arg")]
      def foo
      end
      CRYSTAL
  end

  it "errors if missing link arguments" do
    assert_error <<-CRYSTAL, "too many named arguments (given 1, expected maximum 0)"
      @[Experimental(invalid: "lorem ipsum")]
      def foo
      end
      CRYSTAL
  end
end

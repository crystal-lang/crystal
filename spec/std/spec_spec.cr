require "./spec_helper"

private class SpecException < Exception
  getter value : Int32

  def initialize(@value, msg)
    super(msg)
  end
end

private class NilMimicker
  def ==(a_nil : Nil)
    true
  end
end

describe "Spec matchers" do
  describe "should eq" do
    it "passes for the same value" do
      1.should eq(1)
    end

    pending_diff "should raise an exception with diff when the values are long" do
      xs = (1..100).to_a
      ys = xs[0...50] + [-1] + xs[50...100]
      msg = <<-MSG
        Expected: #{xs.inspect}
             got: #{ys.inspect}

        Difference:
        @@ -48,6 +48,7 @@
          48,
          49,
          50,
        + -1,
          51,
          52,
          53,
        MSG
      expect_raises Spec::AssertionFailed, msg do
        ys.should eq(xs)
      end
    end
  end

  describe "should be_truthy" do
    it "passes for true" do
      true.should be_truthy
    end

    it "passes for some non-nil, non-false value" do
      42.should be_truthy
    end
  end

  describe "should_not be_truthy" do
    it "passes for false" do
      false.should_not be_truthy
    end

    it "passes for nil" do
      nil.should_not be_truthy
    end
  end

  describe "should be_falsey" do
    it "passes for false" do
      false.should be_falsey
    end

    it "passes for nil" do
      nil.should be_falsey
    end
  end

  describe "should_not be_falsey" do
    it "passes for true" do
      true.should_not be_falsey
    end

    it "passes for some non-nil, non-false value" do
      42.should_not be_falsey
    end
  end

  describe "be_nil" do
    it "passes for nil" do
      nil.should be_nil
    end

    it "does not pass for overwritten `==`" do
      NilMimicker.new.should_not be_nil
    end
  end

  describe "should contain" do
    it "passes when string includes? specified substring" do
      "hello world!".should contain("hello")
    end

    it "works with array" do
      [1, 2, 3, 5, 8].should contain(5)
    end

    it "works with set" do
      [1, 2, 3, 5, 8].to_set.should contain(8)
    end

    it "works with range" do
      (50..55).should contain(53)
    end

    it "does not pass when string does not includes? specified substring" do
      expect_raises Spec::AssertionFailed, %{Expected:   "hello world!"\nto include: "crystal"} do
        "hello world!".should contain("crystal")
      end
    end
  end

  describe "should_not contain" do
    it "passes when string does not includes? specified substring" do
      "hello world!".should_not contain("crystal")
    end

    it "does not pass when string does not includes? specified substring" do
      expect_raises Spec::AssertionFailed, %{Expected: value "hello world!"\nto not include: "world"} do
        "hello world!".should_not contain("world")
      end
    end
  end

  describe "expect_raises" do
    it "return exception" do
      ex = expect_raises(SpecException) { raise SpecException.new(11, "O_o") }
      ex.value.should eq 11
      ex.message.should eq "O_o"
    end
  end

  context "should work like describe" do
    it "is true" do
      true.should be_truthy
    end
  end

  it "detects a nesting `it`" do
    ex = expect_raises(Spec::NestingSpecError) { it { } }
    ex.message.should eq "can't nest `it` or `pending`"
    ex.file.should eq __FILE__
  end

  it "detects a nesting `pending`" do
    ex = expect_raises(Spec::NestingSpecError) { pending }
    ex.message.should eq "can't nest `it` or `pending`"
    ex.file.should eq __FILE__
  end

  describe "pending block is not compiled" do
    pending "pending has block with valid syntax, but invalid semantics" do
      UndefinedConstant.undefined_method
    end
  end
end

describe "Spec" do
  describe "use_colors?" do
    it "returns if output is colored or not" do
      saved = Spec.use_colors?
      begin
        Spec.use_colors = false
        Spec.use_colors?.should be_false
        Spec.use_colors = true
        Spec.use_colors?.should be_true
      ensure
        Spec.use_colors = saved
      end
    end
  end
end

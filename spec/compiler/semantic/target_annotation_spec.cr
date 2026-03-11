require "../spec_helper"

describe "Semantic: TargetFeature annotation" do
  it "errors if invalid argument provided" do
    assert_error <<-CRYSTAL, "no argument named 'invalid', expected 'cpu'"
      @[TargetFeature(invalid: "lorem ipsum")]
      def foo
      end
      CRYSTAL
  end

  it "errors if invalid cpu argument type provided" do
    assert_error <<-CRYSTAL, "expected argument 'cpu' to be String"
      @[TargetFeature(cpu: 3)]
      def foo
      end
      CRYSTAL
  end

  it "errors if invalid cpu argument type provided and feature provided" do
    assert_error <<-CRYSTAL, "expected argument 'cpu' to be String"
      @[TargetFeature("+sve", cpu: 4)]
      def foo
      end
      CRYSTAL
  end

  it "errors if invalid feature argument type provided" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'TargetFeature' to be String"
      @[TargetFeature(3)]
      def foo
      end
      CRYSTAL
  end

  it "errors if invalid feature argument type provided and cpu provided" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'TargetFeature' to be String"
      @[TargetFeature(3, cpu: "apple-m1")]
      def foo
      end
      CRYSTAL
  end

  it "errors if wrong number of arguments provided" do
    assert_error <<-CRYSTAL, "wrong number of arguments for TargetFeature (given 2, expected 0..1)"
      @[TargetFeature("+sve", "+sve2")]
      def foo
      end
      CRYSTAL
  end

  it "can target a specific LLVM supported feature" do
    assert_type(<<-CRYSTAL) { float64 }
      # This feature is available on all platforms
      @[TargetFeature("+soft-float")]
      def no_hardware_floating_points(input : Float64) : Float64
        input / 2.0
      end

      no_hardware_floating_points(4.0)
      CRYSTAL
  end
end

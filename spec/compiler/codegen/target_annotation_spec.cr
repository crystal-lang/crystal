require "../spec_helper"

describe "Code gen: TargetFeature annotation" do
  it "can target optional CPU features" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      # This feature is available on all platforms
      @[TargetFeature("+soft-float")]
      def no_hardware_floating_points(input : Float64) : Float64
        input / 2.0
      end

      output = no_hardware_floating_points(4.0)
      output == 2.0
      CRYSTAL
  end

  it "can optimize code for a specific CPU" do
    run(<<-CRYSTAL).to_i.should be > 0
      require "prelude"

      {% if flag?(:aarch64) %}
        @[TargetFeature(cpu: "apple-m1")]
      {% elsif flag?(:x86_64) %}
        @[TargetFeature(cpu: "x86-64-v4")]
      {% end %}
      def foo
        [1, 2, 3].sample
      end
      foo
      CRYSTAL
  end

  it "can target optional CPU features and optimize code for a specific CPU" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      {% if flag?(:aarch64) %}
        @[TargetFeature("+soft-float", cpu: "apple-m1")]
      {% elsif flag?(:x86_64) %}
        @[TargetFeature("+soft-float", cpu: "x86-64-v4")]
      {% end %}
      def no_hardware_floating_points(input : Float64) : Float64
        input / 2.0
      end

      output = no_hardware_floating_points(4.0)
      output == 2.0
      CRYSTAL
  end
end

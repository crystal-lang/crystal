require "../spec_helper"

describe "Code gen: TargetFeature annotation" do
  it "can target optional CPU features" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      # This feature is available on all platforms
      @[TargetFeature("+strict-align")]
      def strict_align(input : Int32) : Int32
        input * 2
      end

      output = strict_align(1)
      output == 2
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
        @[TargetFeature("+strict-align", cpu: "apple-m1")]
      {% elsif flag?(:x86_64) %}
        @[TargetFeature("+strict-align", cpu: "x86-64-v4")]
      {% end %}
      def strict_align(input : Int32) : Int32
        input * 2
      end

      output = strict_align(1)
      output == 2
      CRYSTAL
  end
end

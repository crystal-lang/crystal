require "../spec_helper"

describe "Code gen: TargetFeature annotation" do
  it "can target optional CPU features" do
    compile(<<-CRYSTAL)
      require "prelude"

      @[TargetFeature("+sve,+sve2")]
      def sve2_smoke_test : Nil
        asm("ext z0.b, { z1.b, z2.b }, #0" :::: "volatile")
        nil
      end
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
    compile(<<-CRYSTAL)
      require "prelude"

      @[TargetFeature("+sve,+sve2", cpu: "apple-m1")]
      def sve2_smoke_test : Nil
        asm("ext z0.b, { z1.b, z2.b }, #0" :::: "volatile")
        nil
      end
      CRYSTAL
  end
end

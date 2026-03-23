require "../spec_helper"

describe "Code gen: TargetFeature annotation" do
  it "can target optional CPU features" do
    {% if compare_versions(Crystal::LLVM_VERSION, "13.0.0") < 0 %} pending! "requires LLVM 13+" {% end %}

    compile(<<-CRYSTAL, target: "aarch64-darwin")
      @[TargetFeature("+sve,+sve2")]
      def sve2_smoke_test : Nil
        asm("ext z0.b, { z1.b, z2.b }, #0" :::: "volatile")
        nil
      end

      sve2_smoke_test
      CRYSTAL
  end

  it "can optimize code for a specific CPU" do
    {% if compare_versions(Crystal::LLVM_VERSION, "13.0.0") < 0 %} pending! "requires LLVM 13+" {% end %}

    compile(<<-CRYSTAL, prelude: "prelude", target: "x86_64-linux-gnu")
      @[TargetFeature(cpu: "x86-64-v3")]
      def foo
        [1, 2, 3].sample
      end

      foo
      CRYSTAL
  end

  it "can target optional CPU features and optimize code for a specific CPU" do
    {% if compare_versions(Crystal::LLVM_VERSION, "13.0.0") < 0 %} pending! "requires LLVM 13+" {% end %}

    compile(<<-CRYSTAL, target: "aarch64-darwin")
      @[TargetFeature("+sve,+sve2", cpu: "apple-m1")]
      def sve2_smoke_test : Nil
        asm("ext z0.b, { z1.b, z2.b }, #0" :::: "volatile")
        nil
      end

      sve2_smoke_test
      CRYSTAL
  end
end

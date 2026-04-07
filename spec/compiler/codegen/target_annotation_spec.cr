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

    # unlike the ARM backend, the X86 backend doesn't validate assembly
    # instructions, but the LLVM intrinsics are validated so we use one
    compile(<<-CRYSTAL, target: "x86_64-linux-gnu")
      lib LibIntrinsics
        fun x86_avx_vzeroall = "llvm.x86.avx.vzeroall"
      end

      @[TargetFeature(cpu: "x86-64-v3")]
      def x86_vzeroall : Nil
        LibIntrinsics.x86_avx_vzeroall
      end

      x86_vzeroall
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

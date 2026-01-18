require "../spec_helper"

describe "Code gen: Target annotation" do
  it "errors if invalid Target argument provided" do
    assert_error <<-CRYSTAL, "invalid Target argument 'invalid'. Valid arguments are features, cpu"
      @[Target(invalid: "lorem ipsum")]
      def foo
      end
      CRYSTAL
  end

  it "can target optional CPU features" do
    {% if flag?(:aarch64) %}
      run(<<-CRYSTAL).should be_nil
        # SVE2-only instruction (will fail unless +sve,+sve2 enabled)
        @[Target(features: "+sve,+sve2")]
        def sve2_smoke_test : Nil
          asm("ext z0.b, { z1.b, z2.b }, #0" :::: "volatile")
          nil
        end

        enum Supported
          NEON
          SVE
          SVE2
        end

        supported = Supported::NEON

        # Don’t call it; we only care that it compiles.
        case supported
        when .sve2?
          sve2_smoke_test
        end

        nil
        CRYSTAL
    {% else %}
      pending! "no strictly optional features on this architecture"
    {% end %}
  end

  it "can optimize code for a specific CPU" do
    {% if flag?(:aarch64) %}
      run(<<-CRYSTAL).should be >= 0
        @[Target(cpu: "apple-m4")]
        def foo
          rand(10)
        end
        foo
        CRYSTAL
    {% elsif flag?(:x86_64) %}
      run(<<-CRYSTAL).should be >= 0
        @[Target(cpu: "znver4")]
        def foo
          rand(10)
        end
        foo
        CRYSTAL
    {% else %}
      pending! "no CPU specified for this architecture"
    {% end %}
  end
end

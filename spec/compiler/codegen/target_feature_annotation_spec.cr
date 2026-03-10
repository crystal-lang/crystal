require "../spec_helper"

describe "Code gen: TargetFeature annotation" do
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

  it "errors if invalid feature argument type provided" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'TargetFeature' to be String"
      @[TargetFeature(3)]
      def foo
      end
      CRYSTAL
  end

  it "errors wrong number of arguments provided" do
    assert_error <<-CRYSTAL, "wrong number of arguments for TargetFeature (given 2, expected 0..1)"
      @[TargetFeature("+sve", "+sve2")]
      def foo
      end
      CRYSTAL
  end

  it "can target optional CPU features" do
    {% if flag?(:aarch64) %}
      run(<<-CRYSTAL).to_b.should be_true
        require "prelude"

        # SVE2-only instruction (will fail unless +sve,+sve2 enabled)
        @[TargetFeature("+sve,+sve2")]
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

        true
        CRYSTAL
    {% else %}
      pending! "no strictly optional features on this architecture"
    {% end %}
  end

  it "can optimize code for a specific CPU" do
    {% if flag?(:aarch64) %}
      run(<<-CRYSTAL).to_i.should be > 0
        require "prelude"

        @[TargetFeature(cpu: "apple-m1")]
        def foo
          [1, 2, 3].sample
        end
        foo
        CRYSTAL
    {% elsif flag?(:x86_64) %}
      run(<<-CRYSTAL).to_i.should be > 0
        require "prelude"

        @[TargetFeature(cpu: "znver1")]
        def foo
          [1, 2, 3].sample
        end
        foo
        CRYSTAL
    {% else %}
      pending! "no CPU specified for this architecture"
    {% end %}
  end
end

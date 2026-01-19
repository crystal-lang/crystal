require "../spec_helper"

describe "Code gen: Target annotation" do
  it "errors if invalid Target argument provided" do
    assert_error <<-CRYSTAL, "invalid Target argument 'invalid'. Valid arguments are features, optimize, debug, cpu"
      @[Target(invalid: "lorem ipsum")]
      def foo
      end
      CRYSTAL
  end

  it "errors if invalid debug value provided" do
    assert_error <<-CRYSTAL, "invalid value for debug argument. Must be true or false"
      @[Target(debug: "all")]
      def foo
      end
      CRYSTAL
  end

  it "errors if invalid optimize value provided" do
    assert_error <<-CRYSTAL, "invalid value for optimize argument. Must be Size or None"
      @[Target(optimize: Everything)]
      def foo
      end
      CRYSTAL
  end

  it "can target optional CPU features" do
    {% if flag?(:aarch64) %}
      run(<<-CRYSTAL).to_b.should be_true
        require "prelude"

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

        @[Target(cpu: "apple-m1")]
        def foo
          [1, 2, 3].sample
        end
        foo
        CRYSTAL
    {% elsif flag?(:x86_64) %}
      run(<<-CRYSTAL).to_i.should be > 0
        require "prelude"

        @[Target(cpu: "znver1")]
        def foo
          [1, 2, 3].sample
        end
        foo
        CRYSTAL
    {% else %}
      pending! "no CPU specified for this architecture"
    {% end %}
  end

  it "can disable debug metadata" do
    run(<<-CRYSTAL).to_string.should contain("in '??'")
      require "prelude"

      @[Target(debug: false)]
      def foo
        raise "error"
      end

      begin
        foo
      rescue error
        puts error.backtrace[0..4]
      end
      CRYSTAL
  end

  it "can adjust optimizations" do
    run(<<-CRYSTAL).to_b.should be_true
      @[Target(optimize: :size)]
      def size
        true
      end

      @[Target(optimize: :none)]
      def none
        true
      end

      size && none
      CRYSTAL
  end
end

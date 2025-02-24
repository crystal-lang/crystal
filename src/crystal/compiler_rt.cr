{% skip_file if flag?(:skip_crystal_compiler_rt) %}

require "./compiler_rt/fixint.cr"
require "./compiler_rt/float.cr"
require "./compiler_rt/mul.cr"
require "./compiler_rt/divmod128.cr"

{% if flag?(:arm) || flag?(:wasm32) %}
  # __multi3 was only missing on arm and wasm32
  require "./compiler_rt/multi3.cr"
{% end %}

{% if flag?(:wasm32) %}
  # __ashlti3, __ashrti3 and __lshrti3 are missing on wasm32
  require "./compiler_rt/shift.cr"

  # __powisf2 and __powidf2 are missing on wasm32
  require "./compiler_rt/pow.cr"
{% end %}

{% if flag?(:win32) && flag?(:bits64) %}
  # LLVM doesn't honor the Windows x64 ABI when calling certain compiler-rt
  # functions from its own instructions, but calls from Crystal do, so we invoke
  # those functions directly
  # note that the following defs redefine the ones in `primitives.cr`

  # https://github.com/llvm/llvm-project/commit/4a406d32e97b1748c4eed6674a2c1819b9cf98ea
  struct Int128
    {% for int2 in [Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128] %}
      @[AlwaysInline]
      def unsafe_div(other : {{ int2.id }}) : self
        __divti3(self, other.to_i128!)
      end

      @[AlwaysInline]
      def unsafe_mod(other : {{ int2.id }}) : self
        __modti3(self, other.to_i128!)
      end
    {% end %}
  end

  struct UInt128
    {% for int2 in [Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128] %}
      @[AlwaysInline]
      def unsafe_div(other : {{ int2.id }}) : self
        __udivti3(self, other.to_u128!)
      end

      @[AlwaysInline]
      def unsafe_mod(other : {{ int2.id }}) : self
        __umodti3(self, other.to_u128!)
      end
    {% end %}
  end

  {% for int1 in [Int8, Int16, Int32, Int64] %}
    {% for int2 in [Int128, UInt128] %}
      struct {{ int1.id }}
        @[AlwaysInline]
        def unsafe_div(other : {{ int2.id }}) : self
          {{ int1.id }}.new!(__divti3(self.to_i128!, other.to_i128!))
        end

        @[AlwaysInline]
        def unsafe_mod(other : {{ int2.id }}) : self
          {{ int1.id }}.new!(__modti3(self.to_i128!, other.to_i128!))
        end
      end
    {% end %}
  {% end %}

  {% for int1 in [UInt8, UInt16, UInt32, UInt64] %}
    {% for int2 in [Int128, UInt128] %}
      struct {{ int1.id }}
        @[AlwaysInline]
        def unsafe_div(other : {{ int2.id }}) : self
          {{ int1.id }}.new!(__udivti3(self.to_u128!, other.to_u128!))
        end

        @[AlwaysInline]
        def unsafe_mod(other : {{ int2.id }}) : self
          {{ int1.id }}.new!(__umodti3(self.to_u128!, other.to_u128!))
        end
      end
    {% end %}
  {% end %}

  # https://github.com/llvm/llvm-project/commit/d6216e2cd1a5e07f8509215ee5422ff5ee358da8
  {% if compare_versions(Crystal::LLVM_VERSION, "14.0.0") >= 0 %}
    # the following overflow comparisons must be identical to the ones in
    # `Crystal::CodeGenVisitor#codegen_out_of_range`

    struct Int128
      @[AlwaysInline]
      def to_f32 : Float32
        __floattisf(self)
      end

      @[AlwaysInline]
      def to_f64 : Float64
        __floattidf(self)
      end
    end

    struct UInt128
      @[AlwaysInline]
      def to_f32 : Float32
        # Float32::MAX.to_u128! (it is okay to use a literal here because
        # support for LLVM 14 was added after 128-bit literals)
        if self > 340282346638528859811704183484516925440_u128
          raise OverflowError.new
        end
        __floatuntisf(self)
      end

      @[AlwaysInline]
      def to_f64 : Float64
        __floatuntidf(self)
      end
    end

    struct Float32
      @[AlwaysInline]
      def to_i128 : Int128
        # Int128::MIN.to_f32!..Int128::MAX.to_f32!.prev_float
        if !(self >= -1.7014118e+38_f32) || self > 1.7014117e+38_f32
          raise OverflowError.new
        end
        __fixsfti(self)
      end

      @[AlwaysInline]
      def to_u128 : UInt128
        # UInt128::MIN.to_f32!..Float32::MAX
        if !(self >= 0_f32) || self > 3.4028235e+38_f32
          raise OverflowError.new
        end
        __fixunssfti(self)
      end
    end

    struct Float64
      @[AlwaysInline]
      def to_i128 : Int128
        # Int128::MIN.to_f64!..Int128::MAX.to_f64!.prev_float
        if !(self >= -1.7014118346046923e+38_f64) || self > 1.7014118346046921e+38_f64
          raise OverflowError.new
        end
        __fixdfti(self)
      end

      @[AlwaysInline]
      def to_u128 : UInt128
        # UInt128::MIN.to_f64!..UInt128::MAX.to_f64!.prev_float
        if !(self >= 0_f64) || self > 3.4028236692093843e+38_f64
          raise OverflowError.new
        end
        __fixunsdfti(self)
      end
    end

    {% for v in [
                  {Int128, "to_f32", Float32, "__floattisf"},
                  {Int128, "to_f64", Float64, "__floattidf"},
                  {UInt128, "to_f32", Float32, "__floatuntisf"},
                  {UInt128, "to_f64", Float64, "__floatuntidf"},
                  {Float32, "to_i128", Int128, "__fixsfti"},
                  {Float32, "to_u128", UInt128, "__fixunssfti"},
                  {Float64, "to_i128", Int128, "__fixdfti"},
                  {Float64, "to_u128", UInt128, "__fixunsdfti"},
                ] %}
      {% type, method, ret, rt_method = v %}
      struct {{ type.id }}
        @[AlwaysInline]
        def {{ method.id }}! : {{ ret.id }}
          {{ rt_method.id }}(self)
        end
      end
    {% end %}

    {% for op in {"+", "-", "*", "fdiv"} %}
      struct Int128
        @[AlwaysInline]
        def {{ op.id }}(other : Float32) : Float32
          to_f32 {{ op.id }} other
        end

        @[AlwaysInline]
        def {{ op.id }}(other : Float64) : Float64
          to_f64 {{ op.id }} other
        end
      end

      struct UInt128
        @[AlwaysInline]
        def {{ op.id }}(other : Float32) : Float32
          to_f32 {{ op.id }} other
        end

        @[AlwaysInline]
        def {{ op.id }}(other : Float64) : Float64
          to_f64 {{ op.id }} other
        end
      end

      struct Float32
        @[AlwaysInline]
        def {{ op.id }}(other : Int128) : Float32
          self.{{ op.id }}(other.to_f32)
        end

        @[AlwaysInline]
        def {{ op.id }}(other : UInt128) : Float32
          self.{{ op.id }}(other.to_f32)
        end
      end

      struct Float64
        @[AlwaysInline]
        def {{ op.id }}(other : Int128) : Float64
          self.{{ op.id }}(other.to_f64)
        end

        @[AlwaysInline]
        def {{ op.id }}(other : UInt128) : Float64
          self.{{ op.id }}(other.to_f64)
        end
      end
    {% end %}
  {% end %}
{% end %}

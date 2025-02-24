require "../../spec_helper"

describe "Code gen: primitives" do
  it "codegens bool" do
    run("true").to_b.should be_true
    run("false").to_b.should be_false
  end

  it "codegens int" do
    run("1").to_i.should eq(1)
  end

  it "codegens long" do
    run("1_i64").to_i.should eq(1)
  end

  it "codegens int128" do
    # LLVM's JIT doesn't seem to support 128
    # bit integers well regarding GenericValue
    run(%(
      require "prelude"

      1_i128.to_i
      )).to_i.should eq(1)
  end

  it "codegens uint128" do
    # LLVM's JIT doesn't seem to support 128
    # bit integers well regarding GenericValue
    run(%(
      require "prelude"

      1_u128.to_i
      )).to_i.should eq(1)
  end

  it "codegens char" do
    run("'a'").to_i.should eq('a'.ord)
  end

  it "codegens char ord" do
    run("'a'.ord").to_i.should eq('a'.ord)
  end

  it "codegens f32" do
    run("2.5_f32").to_f32.should eq(2.5_f32)
  end

  it "codegens f64" do
    run("2.5_f64").to_f64.should eq(2.5_f64)
  end

  it "codegens string" do
    run(%("foo")).to_string.should eq("foo")
  end

  describe "arithmetic primitives" do
    # more detailed tests are done through the `primitives_spec` suite on a new
    # generation of the compiler

    it "codegens 1 + 2" do
      run(%(require "prelude"; 1 + 2)).to_i.should eq(3)
    end

    it "codegens 1 &+ 2" do
      run(%(1 &+ 2)).to_i.should eq(3)
    end

    it "codegens 1 - 2" do
      run(%(require "prelude"; 1 - 2)).to_i.should eq(-1)
    end

    it "codegens 1 &- 2" do
      run(%(1 &- 2)).to_i.should eq(-1)
    end

    it "codegens 2 * 3" do
      run(%(require "prelude"; 2 * 3)).to_i.should eq(6)
    end

    it "codegens 2 &* 3" do
      run(%(2 &* 3)).to_i.should eq(6)
    end

    it "codegens 8.unsafe_div 3" do
      run(%(8.unsafe_div 3)).to_i.should eq(2)
    end

    it "codegens 8.unsafe_mod 3" do
      run(%(10.unsafe_mod 3)).to_i.should eq(1)
    end

    it "codegens 16.unsafe_shr 2" do
      run(%(16.unsafe_shr 2)).to_i.should eq(4)
    end

    it "codegens 16.unsafe_shl 2" do
      run(%(16.unsafe_shl 2)).to_i.should eq(64)
    end

    it "codegens 1.to_i16!" do
      run("1.to_i16!").to_i.should eq(1)
    end

    it "codegens 1.to_i16" do
      run(%(require "prelude"; 1.to_i16)).to_i.should eq(1)
    end

    it "codegens 1.to_f!" do
      run("1.to_f!").to_f64.should eq(1.0)
    end

    it "codegens 1.to_f" do
      run(%(require "prelude"; 1.to_f)).to_f64.should eq(1.0)
    end

    it "skips bounds checking when to_i produces same type" do
      run("1.to_i32").to_i.should eq(1)
    end
  end

  it "defined method that calls primitive (bug)" do
    run("
      struct Int64
        def foo
          to_u64!
        end
      end

      a = 1_i64
      a.foo.to_i!
      ").to_i.should eq(1)
  end

  it "codegens __LINE__" do
    run("

      __LINE__
      ", inject_primitives: false).to_i.should eq(3)
  end

  it "codegens crystal_type_id with union type" do
    run("
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.allocate || Bar.allocate
      f.crystal_type_id == Foo.allocate.crystal_type_id
      ").to_b.should be_true
  end

  it "doesn't treat `(1 == 1) == true` as `1 == 1 == true` (#328)" do
    run("(1 == 1) == true").to_b.should be_true
  end

  it "passes issue #328" do
    run("((1 == 1) != (2 == 2))").to_b.should be_false
  end

  pending "codegens pointer of int" do
    run(%(
      ptr = Pointer(Int).malloc(1_u64)
      ptr.value = 1
      ptr.value = 2_u8
      ptr.value = 3_u16
      ptr.value = 4_u32
      (ptr.value + 1).to_i32
      )).to_i.should eq(5)
  end

  pending "sums two numbers out of an [] of Number" do
    run(%(
      p = Pointer(Number).malloc(2_u64)
      p.value = 1
      (p + 1_i64).value = 1.5

      (p.value + (p + 1_i64).value).to_f32
      )).to_f32.should eq(2.5)
  end

  it "codegens crystal_type_id for class" do
    codegen(%(String.crystal_type_id))
  end

  it "can invoke cast on primitive typedef (#614)" do
    codegen(%(
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo.to_i!
      ))
  end

  it "can invoke binary on primitive typedef (#614)" do
    codegen(%(
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo &+ 1
      ))
  end

  it "allows redefining a primitive method" do
    run(%(
      struct Int32
        def *(other : Int32)
          42
        end
      end

      1 * 2
      )).to_i.should eq(42)
  end

  it "doesn't optimize away call whose obj is not passed as self (#2226)" do
    run(%(
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo
        Global.x = 2
        3
      end

      foo.class.crystal_type_id

      Global.x
      )).to_i.should eq(2)
  end

  it "uses built-in llvm function that returns a tuple" do
    run(%(
      lib Intrinsics
        fun sadd_i32_with_overflow = "llvm.sadd.with.overflow.i32"(a : Int32, b : Int32) : {Int32, Bool}
      end

      x, o = Intrinsics.sadd_i32_with_overflow(1, 2)
      x
      )).to_i.should eq(3)
  end

  it "gets crystal class instance type id" do
    run(%(
      class Foo
      end

      Foo.new.crystal_type_id == Foo.crystal_instance_type_id
      )).to_b.should be_true
  end

  describe "va_arg" do
    # On Windows and AArch64 llvm's va_arg instruction works incorrectly.
    {% unless flag?(:win32) || flag?(:aarch64) %}
      it "uses llvm's va_arg instruction" do
        mod = codegen(%(
          struct VaList
            @[Primitive(:va_arg)]
            def next(type)
            end
          end

          list = VaList.new
          list.next(Int32)
        ))
        type = {% if LibLLVM::IS_LT_150 %} "%VaList*" {% else %} "ptr" {% end %}
        str = mod.to_s
        str.should contain("va_arg #{type} %list")
      end

      it "works with C code" do
        test_c(
          %(
            extern int foo_f(int,...);
            int foo() {
              return foo_f(3,1,2,3);
            }
          ),
          %(
            lib LibFoo
              fun foo() : LibC::Int
            end

            fun foo_f(count : Int32, ...) : LibC::Int
              sum = 0
              VaList.open do |list|
                count.times do |i|
                  sum += list.next(Int32)
                end
              end
              sum
            end

            LibFoo.foo
          ), &.to_i.should eq(6))
      end
    {% end %}
  end

  describe "atomicrmw" do
    it "codegens atomicrmw with enums" do
      run(<<-CRYSTAL).to_i.should eq(3)
        enum RMWBinOp
          Add = 1
        end

        enum Ordering
          SequentiallyConsistent = 7
        end

        @[Primitive(:atomicrmw)]
        def atomicrmw(op : RMWBinOp, ptr : Int32*, val : Int32, ordering : Ordering, singlethread : Bool) : Int32
        end

        x = 1
        atomicrmw(:add, pointerof(x), 2, :sequentially_consistent, false)
        x
        CRYSTAL
    end

    it "codegens atomicrmw with enums" do
      run(<<-CRYSTAL).to_i.should eq(3)
        enum RMWBinOp
          Add = 1
        end

        enum Ordering
          SequentiallyConsistent = 7
        end

        @[Primitive(:atomicrmw)]
        def atomicrmw(op : RMWBinOp, ptr : Int32*, val : Int32, ordering : Ordering, singlethread : Bool) : Int32
        end

        x = 1
        atomicrmw(RMWBinOp::Add, pointerof(x), 2, Ordering::SequentiallyConsistent, false)
        x
        CRYSTAL
    end

    # TODO: remove once support for 1.4 is dropped
    it "codegens atomicrmw with symbols" do
      run(<<-CRYSTAL).to_i.should eq(3)
        @[Primitive(:atomicrmw)]
        def atomicrmw(op : Symbol, ptr : Int32*, val : Int32, ordering : Symbol, singlethread : Bool) : Int32
        end

        x = 1
        atomicrmw(:add, pointerof(x), 2, :sequentially_consistent, false)
        x
        CRYSTAL
    end
  end

  it "allows @[Primitive] on method that has body" do
    run(%(
      module Moo
        @[Primitive(:symbol_to_s)]
        def self.symbol_to_s(symbol : Symbol) : String
          untyped
        end
      end

      Moo.symbol_to_s(:hello)
      )).to_string.should eq("hello")
  end

  it "allows @[Primitive] on fun declarations" do
    run(%(
      lib LibFoo
        @[Primitive(:enum_value)]
        fun enum_value(x : Int32) : Int32
      end

      LibFoo.enum_value(1)
      )).to_i.should eq(1)
  end
end

require "../../spec_helper"

describe "Semantic: primitives" do
  it "types a bool" do
    assert_type("false") { bool }
  end

  it "types an int32" do
    assert_type("1") { int32 }
  end

  it "types a int64" do
    assert_type("1_i64") { int64 }
  end

  it "types a int128" do
    assert_type("1_i128") { int128 }
  end

  it "types a uint128" do
    assert_type("1_u128") { uint128 }
  end

  it "types a float32" do
    assert_type("2.3_f32") { float32 }
  end

  it "types a float64" do
    assert_type("2.3_f64") { float64 }
  end

  it "types a char" do
    assert_type("'a'") { char }
  end

  it "types char ord" do
    assert_type("'a'.ord", inject_primitives: true) { int32 }
  end

  it "types a symbol" do
    assert_type(":foo") { symbol }
  end

  it "types a string" do
    assert_type("\"foo\"") { string }
  end

  it "types nil" do
    assert_type("nil") { nil_type }
  end

  it "types nop" do
    assert_type("") { nil_type }
  end

  it "types an expression" do
    assert_type("1; 'a'") { char }
  end

  it "types 1 + 2" do
    assert_type("1 + 2", inject_primitives: true) { int32 }
  end

  it "errors when comparing void (#225)" do
    assert_error <<-CRYSTAL, "undefined method '==' for Nil"
      lib LibFoo
        fun foo
      end

      LibFoo.foo == 1
      CRYSTAL
  end

  it "correctly types first hash from type vars (bug)" do
    assert_type(<<-CRYSTAL) { generic_class "Hash", int32, char }
      class Hash(K, V)
      end

      def foo(x : K, y : V) forall K, V
        {} of K => V
      end

      x = foo 1, 'a'
      y = foo 'a', 1
      x
      CRYSTAL
  end

  it "computes correct hash value type if it's a function literal (#320)" do
    assert_type(<<-CRYSTAL) { generic_class "Hash", string, proc_of(bool) }
      require "prelude"

      {"foo" => ->{ true }}
      CRYSTAL
  end

  it "extends from Number and doesn't find + method" do
    assert_error <<-CRYSTAL, "undefined method"
      struct Foo < Number
      end

      Foo.new + 1
      CRYSTAL
  end

  it "extends from Number and doesn't find >= method" do
    assert_error <<-CRYSTAL, "undefined method"
      struct Foo < Number
      end

      Foo.new >= 1
      CRYSTAL
  end

  it "extends from Number and doesn't find to_i method" do
    assert_error <<-CRYSTAL, "undefined method"
      struct Foo < Number
      end

      Foo.new.to_i
      CRYSTAL
  end

  pending "types pointer of int" do
    assert_type(<<-CRYSTAL) { types["Int"] }
      p = Pointer(Int).malloc(1_u64)
      p.value = 1
      p.value
      CRYSTAL
  end

  it "can invoke cast on primitive typedef (#614)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo.to_i
      CRYSTAL
  end

  it "can invoke binary on primitive typedef (#614)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { types["Test"].types["K"] }
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo + 1
      CRYSTAL
  end

  it "can invoke binary on primitive typedef (2) (#614)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { types["Test"].types["K"] }
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo.unsafe_shl 1
      CRYSTAL
  end

  it "errors if using instance variable inside primitive type" do
    assert_error <<-CRYSTAL, "can't use instance variables inside primitive types (at Int32)"
      struct Int32
        def meth
          puts @value
        end
      end

      1.meth
      CRYSTAL
  end

  it "types @[Primitive] method" do
    assert_type(<<-CRYSTAL) { int32 }
      struct Int32
        @[Primitive(:binary)]
        def +(other : Int32) : Int32
        end
      end

      1 + 2
      CRYSTAL
  end

  it "errors if @[Primitive] has no args" do
    assert_error <<-CRYSTAL, "expected Primitive annotation to have one argument"
      struct Int32
        @[Primitive]
        def +(other : Int32) : Int32
        end
      end
      CRYSTAL
  end

  it "errors if @[Primitive] has non-symbol arg" do
    assert_error <<-CRYSTAL, "expected Primitive argument to be a symbol literal"
      struct Int32
        @[Primitive("foo")]
        def +(other : Int32) : Int32
        end
      end
      CRYSTAL
  end

  it "allows @[Primitive] on method that has body" do
    assert_no_errors %(
      struct Int32
        @[Primitive(:binary)]
        def +(other : Int32) : Int32
          1
        end
      end
      )
  end

  it "types va_arg primitive" do
    assert_type(<<-CRYSTAL) { int32 }
      struct VaList
        @[Primitive(:va_arg)]
        def next(type)
        end
      end

      list = VaList.new
      list.next(Int32)
      CRYSTAL
  end

  it "looks up return type in correct scope (#13652)" do
    assert_type(<<-CRYSTAL) { types["A"] }
      class A
      end

      class Foo
        @[Primitive(:foo)]
        def foo : A
        end
      end

      class Bar::A < Foo
      end

      Bar::A.new.foo
      CRYSTAL
  end

  describe "Slice.literal" do
    def_slice_literal = <<-CRYSTAL
      struct Slice(T)
        def initialize(pointer : T*, size : Int32, *, read_only : Bool)
        end

        @[Primitive(:slice_literal)]
        def self.literal(*args)
        end
      end
      CRYSTAL

    context "without element type" do
      it "types primitive int literal" do
        assert_type(<<-CRYSTAL) { generic_class "Slice", int32 }
          #{def_slice_literal}
          Slice.literal(0, 1, 4, 9)
          CRYSTAL

        assert_type(<<-CRYSTAL) { generic_class "Slice", uint8 }
          #{def_slice_literal}
          Slice.literal(1_u8, 2_u8)
          CRYSTAL
      end

      it "types primitive float literal" do
        assert_type(<<-CRYSTAL) { generic_class "Slice", float64 }
          #{def_slice_literal}
          Slice.literal(1.2, 3.4)
          CRYSTAL

        assert_type(<<-CRYSTAL) { generic_class "Slice", float32 }
          #{def_slice_literal}
          Slice.literal(5.6_f32)
          CRYSTAL
      end

      it "errors if empty" do
        assert_error <<-CRYSTAL, "Cannot create empty slice literal without element type"
          #{def_slice_literal}
          Slice.literal
          CRYSTAL
      end

      it "errors if multiple element types are found" do
        assert_error <<-CRYSTAL, "Too many element types for slice literal without generic argument: Int32, UInt8"
          #{def_slice_literal}
          Slice.literal(1, 2_u8)
          CRYSTAL

        assert_error <<-CRYSTAL, "Too many element types for slice literal without generic argument: Float32, Float64"
          #{def_slice_literal}
          Slice.literal(3.0f32, 4.0)
          CRYSTAL
      end

      it "errors if element is not number literal" do
        assert_error <<-CRYSTAL, "Expected NumberLiteral, got StringLiteral"
          #{def_slice_literal}
          Slice.literal("")
          CRYSTAL

        assert_error <<-CRYSTAL, "Expected NumberLiteral, got Var"
          #{def_slice_literal}
          x = 1
          Slice.literal(x)
          CRYSTAL
      end
    end

    context "with element type" do
      it "types primitive int literal" do
        assert_type(<<-CRYSTAL) { generic_class "Slice", uint8 }
          #{def_slice_literal}
          Slice(UInt8).literal(0, 1, 4, 9)
          CRYSTAL
      end

      it "types primitive float literal" do
        assert_type(<<-CRYSTAL) { generic_class "Slice", float64 }
          #{def_slice_literal}
          Slice(Float64).literal(0, 1, 4, 9)
          CRYSTAL
      end

      it "types empty literal" do
        assert_type(<<-CRYSTAL) { generic_class "Slice", int32 }
          #{def_slice_literal}
          Slice(Int32).literal
          CRYSTAL
      end

      it "errors if element type is not primitive int or float" do
        assert_error <<-CRYSTAL, "Only slice literals of primitive integer or float types can be created"
          #{def_slice_literal}
          Slice(String).literal
          CRYSTAL

        assert_error <<-CRYSTAL, "Only slice literals of primitive integer or float types can be created"
          #{def_slice_literal}
          Slice(Bool).literal
          CRYSTAL

        assert_error <<-CRYSTAL, "Only slice literals of primitive integer or float types can be created"
          #{def_slice_literal}
          Slice(Int32 | Int64).literal
          CRYSTAL
      end

      it "errors if element is not number literal" do
        assert_error <<-CRYSTAL, "Expected NumberLiteral, got StringLiteral"
          #{def_slice_literal}
          Slice(Int32).literal("")
          CRYSTAL

        assert_error <<-CRYSTAL, "Expected NumberLiteral, got Var"
          #{def_slice_literal}
          x = 1
          Slice(Int32).literal(x)
          CRYSTAL
      end

      it "errors if element is out of range" do
        assert_error <<-CRYSTAL, "Argument out of range for a Slice(UInt8)"
          #{def_slice_literal}
          Slice(UInt8).literal(-1)
          CRYSTAL

        assert_error <<-CRYSTAL, "Argument out of range for a Slice(UInt8)"
          #{def_slice_literal}
          Slice(UInt8).literal(256)
          CRYSTAL
      end
    end
  end

  describe "Reference.pre_initialize" do
    def_reference_pre_initialize = <<-CRYSTAL
      class Reference
        @[Primitive(:pre_initialize)]
        def self.pre_initialize(address : Pointer)
          {% @type %}
        end
      end
      CRYSTAL

    it "types with reference type" do
      assert_type(<<-CRYSTAL) { types["Foo"] }
        #{def_reference_pre_initialize}

        class Foo
        end

        x = 1
        Foo.pre_initialize(pointerof(x))
        CRYSTAL
    end

    it "types with virtual reference type" do
      assert_type(<<-CRYSTAL) { types["Foo"].virtual_type! }
        #{def_reference_pre_initialize}

        class Foo
        end

        class Bar < Foo
        end

        x = 1
        Bar.as(Foo.class).pre_initialize(pointerof(x))
        CRYSTAL
    end

    it "errors on uninstantiated generic type" do
      assert_error <<-CRYSTAL, "Can't pre-initialize instance of generic class Foo(T) without specifying its type vars"
        #{def_reference_pre_initialize}

        class Foo(T)
        end

        x = 1
        Foo.pre_initialize(pointerof(x))
        CRYSTAL
    end

    it "errors on abstract type" do
      assert_error <<-CRYSTAL, "Can't pre-initialize abstract class Foo"
        #{def_reference_pre_initialize}

        abstract class Foo
        end

        x = 1
        Foo.pre_initialize(pointerof(x))
        CRYSTAL
    end
  end

  describe "Struct.pre_initialize" do
    def_struct_pre_initialize = <<-CRYSTAL
      struct Struct
        @[Primitive(:pre_initialize)]
        def self.pre_initialize(address : Pointer) : Nil
          {% @type %}
        end
      end
      CRYSTAL

    it "errors on abstract type" do
      assert_error <<-CRYSTAL, "Can't pre-initialize abstract struct Foo"
        #{def_struct_pre_initialize}

        abstract struct Foo
        end

        x = 1
        Foo.pre_initialize(pointerof(x))
        CRYSTAL
    end

    it "errors on virtual abstract type" do
      assert_error <<-CRYSTAL, "Can't pre-initialize abstract struct Foo"
        #{def_struct_pre_initialize}

        abstract struct Foo
        end

        struct Bar < Foo
        end

        x = 1
        Bar.as(Foo.class).pre_initialize(pointerof(x))
        CRYSTAL
    end

    it "errors on abstract pointee type" do
      assert_error <<-CRYSTAL, "Can't pre-initialize struct using pointer to abstract struct"
        #{def_struct_pre_initialize}

        abstract struct Foo
        end

        struct Bar < Foo
        end

        x = uninitialized Foo
        Bar.pre_initialize(pointerof(x))
        CRYSTAL
    end
  end
end

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
    assert_type("'a'.ord") { int32 }
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
    assert_type("1 + 2") { int32 }
  end

  it "types sizeof" do
    assert_type("sizeof(Float64)") { int32 }
  end

  it "types instance_sizeof" do
    assert_type("instance_sizeof(Reference)") { int32 }
  end

  it "errors when comparing void (#225)" do
    assert_error %(
      lib LibFoo
        fun foo
      end

      LibFoo.foo == 1
      ), "undefined method '==' for Nil"
  end

  it "correctly types first hash from type vars (bug)" do
    assert_type(%(
      class Hash(K, V)
      end

      def foo(x : K, y : V) forall K, V
        {} of K => V
      end

      x = foo 1, 'a'
      y = foo 'a', 1
      x
      )) { generic_class "Hash", int32, char }
  end

  it "computes correct hash value type if it's a function literal (#320)" do
    assert_type(%(
      require "prelude"

      {"foo" => ->{ true }}
      )) { generic_class "Hash", string, proc_of(bool) }
  end

  it "extends from Number and doesn't find + method" do
    assert_error %(
      struct Foo < Number
      end

      Foo.new + 1
      ),
      "undefined method"
  end

  it "extends from Number and doesn't find >= method" do
    assert_error %(
      struct Foo < Number
      end

      Foo.new >= 1
      ),
      "undefined method"
  end

  it "extends from Number and doesn't find to_i method" do
    assert_error %(
      struct Foo < Number
      end

      Foo.new.to_i
      ),
      "undefined method"
  end

  pending "types pointer of int" do
    assert_type("
      p = Pointer(Int).malloc(1_u64)
      p.value = 1
      p.value
      ") { types["Int"] }
  end

  it "can invoke cast on primitive typedef (#614)" do
    assert_type(%(
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo.to_i
      )) { int32 }
  end

  it "can invoke binary on primitive typedef (#614)" do
    assert_type(%(
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo + 1
      )) { types["Test"].types["K"] }
  end

  it "can invoke binary on primitive typedef (2) (#614)" do
    assert_type(%(
      lib Test
        type K = Int32
        fun foo : K
      end

      Test.foo.unsafe_shl 1
      )) { types["Test"].types["K"] }
  end

  it "errors if using instance variable inside primitive type" do
    assert_error %(
      struct Int32
        def meth
          puts @value
        end
      end

      1.meth
      ),
      "can't use instance variables inside primitive types (at Int32)"
  end

  it "types @[Primitive] method" do
    assert_type(%(
      struct Int32
        @[Primitive(:binary)]
        def +(other : Int32) : Int32
        end
      end

      1 + 2
      )) { int32 }
  end

  it "errors if @[Primitive] has no args" do
    assert_error %(
      struct Int32
        @[Primitive]
        def +(other : Int32) : Int32
        end
      end
      ),
      "expected Primitive attribute to have one argument"
  end

  it "errors if @[Primitive] has non-symbol arg" do
    assert_error %(
      struct Int32
        @[Primitive("foo")]
        def +(other : Int32) : Int32
        end
      end
      ),
      "expected Primitive argument to be a symbol literal"
  end

  it "errors if @[Primitive] method has body" do
    assert_error %(
      struct Int32
        @[Primitive(:binary)]
        def +(other : Int32) : Int32
          1
        end
      end
      ),
      "method marked as Primitive must have an empty body"
  end
end

require "../../spec_helper"

describe "Type inference: fun" do
  it "types empty fun literal" do
    assert_type("-> {}") { |mod| fun_of(mod.nil) }
  end

  it "types int fun literal" do
    assert_type("-> { 1 }") { fun_of(int32) }
  end

  it "types fun call" do
    assert_type("x = -> { 1 }; x.call()") { int32 }
  end

  it "types int -> int fun literal" do
    assert_type("->(x : Int32) { x }") { fun_of(int32, int32) }
  end

  it "types int -> int fun call" do
    assert_type("f = ->(x : Int32) { x }; f.call(1)") { int32 }
  end

  it "types fun pointer" do
    assert_type("def foo; 1; end; ->foo") { fun_of(int32) }
  end

  it "types fun pointer with types" do
    assert_type("def foo(x); x; end; ->foo(Int32)") { fun_of(int32, int32) }
  end

  it "types a fun pointer with generic types" do
    assert_type("def foo(x); end; ->foo(Pointer(Int32))") { |mod| fun_of(pointer_of(int32), mod.nil) }
  end

  it "types fun pointer to instance method" do
    assert_type("
      class Foo
        def initialize
          @x = 1
        end

        def coco
          @x
        end
      end

      foo = Foo.new
      ->foo.coco
    ") { fun_of(int32) }
  end

  it "types fun type spec" do
    assert_type("a = Pointer(Int32 -> Int64).malloc(1_u64)") { pointer_of(fun_of(int32, int64)) }
  end

  it "allows passing fun type if it is typedefed" do
    assert_type("
      lib LibC
        type Callback = Int32 -> Int32
        fun foo(x : Callback) : Float64
      end

      f = ->(x : Int32) { x + 1 }
      LibC.foo f
      ") { float64 }
  end

  assert_syntax_error "a = 1; ->(a : Foo) { }",
                      "function argument 'a' shadows local variable 'a'"

  it "errors when using local varaible with fun argument name" do
    assert_error "->(a : Int32) { }; a",
      "undefined local variable or method 'a'"
  end

  it "allows implicit cast of fun to return void in LibC function" do
    assert_type("
      lib LibC
        fun atexit(fun : -> ) : Int32
      end

      LibC.atexit ->{ 1 }
      ") { int32 }
  end

  it "passes fun pointer as block" do
    assert_type("
      def foo
        yield
      end

      f = -> { 1 }
      foo &f
      ") { int32 }
  end

  it "passes fun pointer as block with arguments" do
    assert_type("
      def foo
        yield 1
      end

      f = ->(x : Int32) { x.to_f }
      foo &f
      ") { float64 }
  end

  it "binds fun literal to arguments and body" do
    assert_type("
      $x = 1
      f = -> { $x }
      $x = 'a'
      f
    ") { fun_of(union_of(int32, char)) }
  end

  it "has fun literal as restriction and works" do
    assert_type("
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32) { x.to_f }
      ") { float64 }
  end

  it "has fun literal as restriction and works when output not specified" do
    assert_type("
      def foo(x : Int32 -> )
        x.call(1)
      end

      foo ->(x : Int32) { x.to_f }
      ") { void }
  end

  it "has fun literal as restriction and errors if output is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32) { x }
      ",
      "no overload matches"
  end

  it "has fun literal as restriction and errors if input is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int64) { x.to_f }
      ",
      "no overload matches"
  end

  it "has fun literal as restriction and errors if lengths is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32, y : Int32) { x.to_f }
      ",
      "no overload matches"
  end

  it "allows passing nil as fun callback" do
    assert_type("
      lib LibC
        type Cb = Int32 ->
        fun bla(Cb) : Int32
      end

      LibC.bla(nil)
      ") { int32 }
  end

  it "disallows casting a fun type to one accepting more arguments" do
    assert_error("
      f = ->(x : Int32) { x.to_f }
      f as Int32, Int32 -> Float64
      ",
      "can't cast")
  end

  it "allows casting a fun type to one with void argument" do
    assert_type("
      f = ->(x : Int32) { x.to_f }
      f as Int32 -> Void
      ") { fun_of [int32, void] }
  end

  it "disallows casting a fun type to one accepting less arguments" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f as -> Float64
      ",
      "can't cast (Int32 -> Float64) to ( -> Float64)"
  end

  it "disallows casting a fun type to one accepting same length argument but different output" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f as Int32 -> Int32
      ",
      "can't cast (Int32 -> Float64) to (Int32 -> Int32)"
  end

  it "disallows casting a fun type to one accepting same length argument but different input" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f as Float64 -> Float64
      ",
      "can't cast (Int32 -> Float64) to (Float64 -> Float64)"
  end

  it "types fun literal hard type inference (1)" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      ->(f : Foo) do
        {Foo.new(f.x), 0}
      end
      )) { fun_of(types["Foo"], tuple_of([no_return, int32])) }
  end

  it "allows implicit cast of fun to return void in non-generic restriction" do
    assert_type("
      def foo(x : ->)
        x
      end

      foo ->{ 1 }
      ") { fun_of(void) }
  end

  it "allows implicit cast of fun to return void in generic restriction" do
    assert_type("
      class Foo(T)
        def foo(x : T)
          x
        end
      end

      foo = Foo(->).new
      foo.foo ->{ 1 }
      ") { fun_of(void) }
  end

  it "types nil or fun type" do
    result = assert_type("1 == 1 ? nil : ->{}") { |mod| union_of(mod.nil, mod.fun_of(mod.nil)) }
    result.node.type.should be_a(NilableFunType)
  end

  it "undefs fun" do
    assert_error %(
      fun foo : Int32
        1
      end

      undef foo

      foo
      ),
      "undefined local variable or method 'foo'"
  end

  it "allows passing NoReturn type for any return type (1)" do
    assert_type("
      lib LibC
        fun exit : NoReturn
      end

      def foo(f : -> Int32)
        f.call
      end

      foo ->{ LibC.exit }
      ") { no_return }
  end

  it "allows passing NoReturn type for any return type (2)" do
    assert_type("
      lib LibC
        fun exit : NoReturn
        fun foo(x : -> Int32) : Int32
      end

      LibC.foo ->{ LibC.exit }
      ") { int32 }
  end

  it "allows passing NoReturn type for any return type (3)" do
    assert_type("
      lib LibC
        fun exit : NoReturn
        struct S
          x : -> Int32
        end
      end

      s = LibC::S.new
      s.x = ->{ LibC.exit }
      s.x
      ") { fun_of(int32) }
  end

  it "allows new on fun type" do
    assert_type("
      alias F = Int32 -> Int32
      F.new { |x| x + 1 }
      ") { fun_of(int32, int32) }
  end

  it "allows new on fun type that is a typedef" do
    assert_type("
      lib LibC
        type F = Int32 -> Int32
      end

      LibC::F.new { |x| x + 1 }
      ") { fun_of(int32, int32) }
  end

  it "allows new on fun type with less block args" do
    assert_type("
      alias F = Int32 -> Int32
      F.new { 1 }
      ") { fun_of(int32, int32) }
  end

  it "says wrong number of block args in new on fun type" do
    assert_error "
      alias F = Int32 -> Int32
      F.new { |x, y| }
      ",
      "wrong number of block arguments for (Int32 -> Int32)#new (2 for 1)"
  end

  it "says wrong return type in new on fun type" do
    assert_error "
      alias F = Int32 -> Int32
      F.new &.to_f
      ",
      "expected new to return Int32, not Float64"
  end

  it "errors if missing argument type in fun literal" do
    assert_error "->(x) { x }",
      "function argument 'x' must have a type"
  end

  it "allows passing function to LibC without specifying types" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32 -> Int32) : Float64
      end

      LibC.foo ->(x) { x + 1 }
      )) { float64 }
  end

  it "allows writing a function type with Function" do
    assert_type(%(
      Function(Int32, Int32)
      )) { fun_of(int32, int32).metaclass }
  end

  it "allows using Function as restriction (1)" do
    assert_type(%(
      def foo(x : Function(Int32, Int32))
        x.call(2)
      end

      foo ->(x : Int32) { x + 1 }
      )) { int32 }
  end

  it "allows using Function as restriction (2)" do
    assert_type(%(
      def foo(x : Function)
        x.call(2)
      end

      foo ->(x : Int32) { x + 1 }
      )) { int32 }
  end

  it "allows using Function as restriction (3)" do
    assert_type(%(
      def foo(x : Function(T, U))
        T
      end

      foo ->(x : Int32) { x + 1 }
      )) { int32.metaclass }
  end

  it "forwards block and computes correct type (bug)" do
    assert_type(%(
      def foo(&block : -> _)
        bar &block
      end

      def bar(&block : -> _)
        block
      end

      foo { 1 }
      foo { "hello" }.call
      )) { string }
  end

  it "doesn't need to deduce type of block if return is void" do
    assert_type(%(
      class Foo
        def initialize
          @bar = 1
        end

        def bar
          @bar
        end
      end

      def foo(&block : Foo ->)
        block
      end

      f = foo { |f| f.bar }
      Foo.new
      f
      )) { fun_of(types["Foo"], void) }
  end

  it "gives correct error message when fun return type is incorrect (#219)" do
    assert_error %(
      lib LibFoo
        fun bar(f : Int32 -> Int32)
      end

      LibFoo.bar ->(x) { 1.1 }
      ),
      "argument 'f' of 'LibFoo#bar' must be a function returning Int32, not Float64"
  end

  it "doesn't capture closured var if using typeof" do
    assert_type(%(
      lib LibFoo
        fun foo(x : ->) : Int32
      end

      a = 1
      LibFoo.foo ->{
        typeof(a)
        2
      }
      )) { int32 }
  end
end

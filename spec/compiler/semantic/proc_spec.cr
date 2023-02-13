require "../../spec_helper"

describe "Semantic: proc" do
  it "types empty proc literal" do
    assert_type("-> {}") { proc_of(nil_type) }
  end

  it "types int proc literal" do
    assert_type("-> { 1 }") { proc_of(int32) }
  end

  it "types proc call" do
    assert_type("x = -> { 1 }; x.call()", inject_primitives: true) { int32 }
  end

  it "types int -> int proc literal" do
    assert_type("->(x : Int32) { x }") { proc_of(int32, int32) }
  end

  it "types int -> int proc call" do
    assert_type("f = ->(x : Int32) { x }; f.call(1)", inject_primitives: true) { int32 }
  end

  it "types proc literal with return type (1)" do
    assert_type("->(x : Int32) : Int32 { x }") { proc_of(int32, int32) }
  end

  it "types proc literal with return type (2)" do
    assert_type("-> : Int32 | String { 1 }") { proc_of(union_of int32, string) }
  end

  it "types proc call with return type" do
    assert_type("x = -> : Int32 | String { 1 }; x.call()", inject_primitives: true) { union_of int32, string }
  end

  it "types proc pointer" do
    assert_type("def foo; 1; end; ->foo") { proc_of(int32) }
  end

  it "types proc pointer with types" do
    assert_type("def foo(x); x; end; ->foo(Int32)") { proc_of(int32, int32) }
  end

  it "types a proc pointer with generic types" do
    assert_type("def foo(x); end; ->foo(Pointer(Int32))") { proc_of(pointer_of(int32), nil_type) }
  end

  it "types proc pointer to instance method" do
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
    ") { proc_of(int32) }
  end

  it "types proc type spec" do
    assert_type("a = Pointer(Int32 -> Int64).malloc(1_u64)", inject_primitives: true) { pointer_of(proc_of(int32, int64)) }
  end

  it "allows passing proc type if it is a lib alias" do
    assert_type("
      lib LibC
        alias Callback = Int32 -> Int32
        fun foo(x : Callback) : Float64
      end

      f = ->(x : Int32) { x + 1 }
      LibC.foo f
      ", inject_primitives: true) { float64 }
  end

  it "allows passing proc type if it is typedef'd" do
    assert_type("
      lib LibC
        type Callback = Int32 -> Int32
        fun foo : Callback
        fun bar(x : Callback) : Float64
      end

      LibC.bar LibC.foo
      ") { float64 }
  end

  it "errors when using local variable with proc argument name" do
    assert_error "->(a : Int32) { }; a",
      "undefined local variable or method 'a'"
  end

  it "allows implicit cast of proc to return void in LibC function" do
    assert_type("
      lib LibC
        fun atexit(fun : -> ) : Int32
      end

      LibC.atexit ->{ 1 }
      ") { int32 }
  end

  it "passes proc pointer as block" do
    assert_type("
      def foo
        yield
      end

      f = -> { 1 }
      foo &f
      ", inject_primitives: true) { int32 }
  end

  it "passes proc pointer as block with arguments" do
    assert_type("
      def foo
        yield 1
      end

      f = ->(x : Int32) { x.to_f }
      foo &f
      ", inject_primitives: true) { float64 }
  end

  it "binds proc literal to arguments and body" do
    assert_type("
      x = 1
      f = -> { x }
      x = 'a'
      f
    ") { proc_of(union_of(int32, char)) }
  end

  it "has proc literal as restriction and works" do
    assert_type("
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32) { x.to_f }
      ", inject_primitives: true) { float64 }
  end

  it "has proc literal as restriction and works when output not specified" do
    assert_type("
      def foo(x : Int32 -> )
        x.call(1)
      end

      foo ->(x : Int32) { x.to_f }
      ", inject_primitives: true) { nil_type }
  end

  it "has proc literal as restriction and errors if output is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32) { x }
      ",
      "expected argument #1 to 'foo' to be Proc(Int32, Float64), not Proc(Int32, Int32)"
  end

  it "has proc literal as restriction and errors if input is different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int64) { x.to_f }
      ",
      "expected argument #1 to 'foo' to be Proc(Int32, Float64), not Proc(Int64, Float64)", inject_primitives: true
  end

  it "has proc literal as restriction and errors if sizes are different" do
    assert_error "
      def foo(x : Int32 -> Float64)
        x.call(1)
      end

      foo ->(x : Int32, y : Int32) { x.to_f }
      ",
      "expected argument #1 to 'foo' to be Proc(Int32, Float64), not Proc(Int32, Int32, Float64)", inject_primitives: true
  end

  it "allows passing nil as proc callback if it is a lib alias" do
    assert_type("
      lib LibC
        alias Cb = Int32 ->
        fun bla(x : Cb) : Int32
      end

      LibC.bla(nil)
      ") { int32 }
  end

  it "disallows casting a proc type to one accepting more arguments" do
    assert_error("
      f = ->(x : Int32) { x.to_f }
      f.as(Int32, Int32 -> Float64)
      ",
      "can't cast", inject_primitives: true)
  end

  it "allows casting a proc type to one with void argument" do
    assert_type("
      f = ->(x : Int32) { x.to_f }
      f.as(Int32 -> Void)
      ", inject_primitives: true) { proc_of [int32, void] }
  end

  it "disallows casting a proc type to one accepting less arguments" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f.as(-> Float64)
      ",
      "can't cast Proc(Int32, Float64) to Proc(Float64)", inject_primitives: true
  end

  it "disallows casting a proc type to one accepting same size argument but different output" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f.as(Int32 -> Int32)
      ",
      "can't cast Proc(Int32, Float64) to Proc(Int32, Int32)", inject_primitives: true
  end

  it "disallows casting a proc type to one accepting same size argument but different input" do
    assert_error "
      f = ->(x : Int32) { x.to_f }
      f.as(Float64 -> Float64)
      ",
      "can't cast Proc(Int32, Float64) to Proc(Float64, Float64)", inject_primitives: true
  end

  it "errors if inferred return type doesn't match return type restriction (1)" do
    assert_error "-> : Int32 { true }", "expected Proc to return Int32, not Bool"
  end

  it "errors if inferred return type doesn't match return type restriction (2)" do
    assert_error "->(x : Int32) : Int32 { x || 'a' }", "expected Proc to return Int32, not (Char | Int32)"
  end

  it "types proc literal hard type inference (1)" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      ->(f : Foo) do
        {Foo.new(f.x), 0}
      end
      )) { proc_of(types["Foo"], tuple_of([types["Foo"], int32])) }
  end

  it "allows implicit cast of proc to return void in non-generic restriction" do
    assert_type("
      def foo(x : ->)
        x
      end

      foo ->{ 1 }
      ") { proc_of(void) }
  end

  it "allows implicit cast of proc to return void in generic restriction" do
    assert_type("
      class Foo(T)
        def foo(x : T)
          x
        end
      end

      foo = Foo(->).new
      foo.foo ->{ 1 }
      ") { proc_of(void) }
  end

  it "types nil or proc type" do
    result = assert_type("1 == 1 ? nil : ->{}", inject_primitives: true) { nilable proc_of(nil_type) }
    result.node.type.should be_a(NilableProcType)
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
      ", inject_primitives: true) { no_return }
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
      ") { proc_of(int32) }
  end

  it "allows passing NoReturn type for any return type, with Proc notation (#12126)" do
    assert_type("
      lib LibC
        fun exit : NoReturn
      end

      def foo(f : Proc(Int32))
        f.call
      end

      foo ->{ LibC.exit }
      ", inject_primitives: true) { no_return }
  end

  it "allows new on proc type" do
    assert_type("
      #{proc_new}

      alias Func = Int32 -> Int32
      Func.new { |x| x + 1 }
      ", inject_primitives: true) { proc_of(int32, int32) }
  end

  it "allows new on proc type that is a lib alias" do
    assert_type("
      #{proc_new}

      lib LibC
        alias F = Int32 -> Int32
      end

      LibC::F.new { |x| x + 1 }
      ", inject_primitives: true) { proc_of(int32, int32) }
  end

  it "allows new on proc type with less block params" do
    assert_type("
      #{proc_new}

      alias Func = Int32 -> Int32
      Func.new { 1 }
      ") { proc_of(int32, int32) }
  end

  it "says wrong number of block params in new on proc type" do
    assert_error "
      #{proc_new}

      alias Alias = Int32 -> Int32
      Alias.new { |x, y| }
      ",
      "wrong number of block parameters (given 2, expected 1)"
  end

  it "says wrong return type in new on proc type" do
    assert_error "
      #{proc_new}

      alias Alias = Int32 -> Int32
      Alias.new &.to_f
      ",
      "expected block to return Int32, not Float64", inject_primitives: true
  end

  it "errors if missing argument type in proc literal" do
    assert_error "->(x) { x }",
      "parameter 'x' of Proc literal must have a type"
  end

  it "allows passing function to LibC without specifying types" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32 -> Int32) : Float64
      end

      LibC.foo ->(x) { x + 1 }
      ), inject_primitives: true) { float64 }
  end

  it "allows passing function to LibC without specifying types, using a global method" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32 -> Int32) : Float64
      end

      def callback(x)
        x + 1
      end

      LibC.foo ->callback
      ), inject_primitives: true) { float64 }
  end

  it "allows passing function to LibC without specifying types, using a class method" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32 -> Int32) : Float64
      end

      class Foo
        def self.callback(x)
          x + 1
        end
      end

      LibC.foo ->Foo.callback
      ), inject_primitives: true) { float64 }
  end

  it "allows writing a function type with Proc" do
    assert_type(%(
      Proc(Int32, Int32)
      )) { proc_of(int32, int32).metaclass }
  end

  it "allows using Proc as restriction (1)" do
    assert_type(%(
      def foo(x : Proc(Int32, Int32))
        x.call(2)
      end

      foo ->(x : Int32) { x + 1 }
      ), inject_primitives: true) { int32 }
  end

  it "allows using Proc as restriction (2)" do
    assert_type(%(
      def foo(x : Proc)
        x.call(2)
      end

      foo ->(x : Int32) { x + 1 }
      ), inject_primitives: true) { int32 }
  end

  it "allows using Proc as restriction (3)" do
    assert_type(%(
      def foo(x : Proc(T, U)) forall T, U
        T
      end

      foo ->(x : Int32) { x + 1 }
      ), inject_primitives: true) { int32.metaclass }
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
      ), inject_primitives: true) { string }
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
      )) { proc_of(types["Foo"], nil_type) }
  end

  it "gives correct error message when proc return type is incorrect (#219)" do
    assert_error %(
      lib LibFoo
        fun bar(f : Int32 -> Int32)
      end

      LibFoo.bar ->(x) { 1.1 }
      ),
      "argument 'f' of 'LibFoo#bar' must be a Proc returning Int32, not Float64"
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

  it "types proc literal with a type that was never instantiated" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      ->(s : Foo) { s.x }
      )) { proc_of(types["Foo"], int32) }
  end

  it "types proc pointer with a type that was never instantiated" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      def foo(f : Foo)
        Foo.new(f.x)
      end

      ->foo(Foo)
      )) { proc_of(types["Foo"], types["Foo"]) }
  end

  it "allows using proc arg name shadowing local variable" do
    assert_type(%(
      a = 1
      f = ->(a : String) { }
      a
      )) { int32 }
  end

  it "uses array argument of proc arg (1)" do
    assert_type(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      def foo(&block : Array(Foo) -> Foo)
      end

      block = foo { |elems| elems[0] }
      elems = [Foo.new, Bar.new]
      block
      )) { nil_type }
  end

  it "uses array argument of proc arg (2)" do
    assert_type(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      def foo(&block : Array(Foo) -> Foo)
        block
      end

      block = foo { |elems| elems[0] }
      elems = [Foo.new, Bar.new]
      block
      )) { proc_of(array_of(types["Foo"].virtual_type), types["Foo"].virtual_type) }
  end

  it "uses array argument of proc arg (3)" do
    assert_type(%(
      require "prelude"

      class Foo
      end

      class Bar < Foo
        getter value

        def initialize(@value : Int32)
        end
      end

      def foo(&block : Array(Foo) -> Foo)
        block
      end

      block = foo { |elems| Bar.new(elems[0].as(Bar).value) }
      elems = [Foo.new, Bar.new(1)]
      block
      )) { proc_of(array_of(types["Foo"].virtual_type), types["Foo"].virtual_type) }
  end

  it "uses array argument of proc arg (4)" do
    assert_error %(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      def foo(&block : Array(Foo) -> Foo)
        block
      end

      block = foo { |elems| 1 }
      block.call [Foo.new, Bar.new]
      ),
      "expected block to return Foo, not Int32"
  end

  it "doesn't let passing an non-covariant generic argument" do
    assert_error %(
      require "prelude"

      class Foo
      end

      class Bar < Foo
      end

      def foo(&block : Array(Foo) -> Foo)
        block
      end

      f = ->(x : Array(Foo)) {}
      f.call [Bar.new]
      ),
      "no overload matches"
  end

  it "allows invoking a function with a generic subtype (1)" do
    assert_type(%(
      module Moo
        def foo
          1
        end
      end

      class Foo(T)
        include Moo
      end

      def func(&block : Moo -> _)
        block
      end

      foo = Foo(Int32).new
      f = func { |moo| moo.foo }
      f.call foo
      ), inject_primitives: true) { int32 }
  end

  it "allows invoking a function with a generic subtype (2)" do
    assert_type(%(
      module Moo(T)
        def foo
          1
        end
      end

      class Foo(T)
        include Moo(T)
      end

      def func(&block : Moo(Int32) -> _)
        block
      end

      foo = Foo(Int32).new
      f = func { |moo| moo.foo }
      f.call foo
      ), inject_primitives: true) { int32 }
  end

  it "gets pointer to lib fun without specifying types" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Int32) : Float64
      end

      ->LibFoo.foo
      )) { proc_of(int32, float64) }
  end

  it "allows passing union including module to proc" do
    assert_type(%(
      module Moo
        def moo
          1
        end
      end

      class Foo
        include Moo
      end

      class Bar
        include Moo
      end

      proc = ->(x : Moo) { x.moo }

      foo = Foo.new || Bar.new
      proc.call(foo)
      ), inject_primitives: true) { int32 }
  end

  it "allows passing virtual type including module to proc" do
    assert_type(%(
      module Moo
        def moo
          1
        end
      end

      class Foo
        include Moo
      end

      class Bar < Foo
      end

      proc = ->(x : Moo) { x.moo }

      foo = Foo.new || Bar.new
      proc.call(foo)
      ), inject_primitives: true) { int32 }
  end

  %w(Object Value Reference Number Int Float Struct Class Proc Tuple Enum StaticArray Pointer).each do |type|
    it "disallows #{type} in procs" do
      assert_error %(
        ->(x : #{type}) { }
        ),
        "can't use #{type} as a Proc argument type"
    end

    it "disallows #{type} in proc return types" do
      assert_error %(
        -> : #{type} { }
        ),
        "can't use #{type} as a Proc argument type"
    end

    it "disallows #{type} in captured block" do
      assert_error %(
        def foo(&block : #{type} ->)
        end

        foo {}
        ),
        "can't use #{type} as a Proc argument type"
    end

    it "disallows #{type} in proc pointer" do
      assert_error %(
        def foo(x)
        end

        ->foo(#{type})
        ),
        "can't use #{type} as a Proc argument type"
    end

    it "disallows #{type} in proc notation parameter type" do
      assert_error "x : #{type} ->", "can't use #{type} as a Proc argument type"
    end

    it "disallows #{type} in proc notation return type" do
      assert_error "x : -> #{type}", "can't use #{type} as a Proc argument type"
    end
  end

  it "allows metaclass in procs" do
    assert_type(<<-CRYSTAL) { proc_of(types["Foo"].metaclass, types["Foo"]) }
      class Foo
      end

      ->(x : Foo.class) { x.new }
      CRYSTAL
  end

  it "allows metaclass in proc return types" do
    assert_type(<<-CRYSTAL) { proc_of(types["Foo"].metaclass) }
      class Foo
      end

      -> : Foo.class { Foo }
      CRYSTAL
  end

  it "allows metaclass in captured block" do
    assert_type(<<-CRYSTAL) { proc_of(types["Foo"].metaclass, types["Foo"]) }
      class Foo
      end

      def foo(&block : Foo.class -> Foo)
        block
      end

      foo { |x| x.new }
      CRYSTAL
  end

  it "allows metaclass in proc pointer" do
    assert_type(<<-CRYSTAL) { proc_of(types["Foo"].metaclass, types["Foo"]) }
      class Foo
      end

      def foo(x : Foo.class)
        x.new
      end

      ->foo(Foo.class)
      CRYSTAL
  end

  it "allows metaclass in proc notation parameter type" do
    assert_type(<<-CRYSTAL) { proc_of(types["Foo"].metaclass, nil_type) }
      class Foo
      end

      #{proc_new}

      x : Foo.class -> = Proc(Foo.class, Nil).new { }
      x
      CRYSTAL
  end

  it "allows metaclass in proc notation return type" do
    assert_type(<<-CRYSTAL) { proc_of(types["Foo"].metaclass) }
      class Foo
      end
      x : -> Foo.class = ->{ Foo }
      x
      CRYSTAL
  end

  it "..." do
    assert_type(%(
      def foo
        ->{ a = 1; return 0 }.call
      end

      foo
      ), inject_primitives: true) { int32 }
  end

  it "doesn't crash on constant to proc pointer" do
    assert_type(%(
      lib LibC
        fun foo
      end

      FOO = ->LibC.foo
      1
      )) { int32 }
  end

  it "sets proc type as void if explicitly told so, when using new" do
    assert_type(%(
      #{proc_new}

      Proc(Int32, Void).new { 1 }
      )) { proc_of(int32, nil_type) }
  end

  it "unpacks tuple but doesn't override local variables, when using new (#9813)" do
    assert_type(%(
      #{proc_new}

      i = 1
      Proc(Tuple(Char), Nil).new do |(x)|

      end.call({'a'})
      i
      ), inject_primitives: true) { int32 }
  end

  it "accesses T and R" do
    assert_type(%(
      struct Proc
        def t
          {T, R}
        end
      end

      ->(x : Int32) { 'a' }.t
      )) { tuple_of([tuple_of([int32]).metaclass, char.metaclass]) }
  end

  it "can match *T in block argument" do
    assert_type(%(
      struct Tuple
        def foo(&block : *T -> U) forall T, U
          yield self[0], self[1]
          U
        end
      end

      {1, 'a'}.foo { |x, y| true }
      )) { bool.metaclass }
  end

  it "says wrong number of arguments" do
    assert_error %(
      ->(x : Int32) { }.call
      ),
      "no overload matches", inject_primitives: true
  end

  it "finds method of object" do
    assert_type(%(
      class Object
        def foo
          1
        end
      end

      ->{}.foo
      )) { int32 }
  end

  it "accesses T inside variadic generic" do
    assert_type(%(
      def foo(proc : Proc(*T, R)) forall T, R
        {T, R}
      end

      foo(->(x : Int32, y : Float64) { 'a' })
      )) { tuple_of([tuple_of([int32, float64]).metaclass, char.metaclass]) }
  end

  it "accesses T inside variadic generic (2)" do
    assert_type(%(
      def foo(proc : Proc(*T, R)) forall T, R
        {T, R}
      end

      foo(->(x : Int32) { 'a' })
      )) { tuple_of([tuple_of([int32]).metaclass, char.metaclass]) }
  end

  it "accesses T inside variadic generic, in proc notation" do
    assert_type(%(
      def foo(proc : *T -> R) forall T, R
        {T, R}
      end

      foo(->(x : Int32, y : Float64) { 'a' })
      )) { tuple_of([tuple_of([int32, float64]).metaclass, char.metaclass]) }
  end

  it "declares an instance variable with splat in proc notation" do
    assert_type(%(
      class Foo
        @x : *{Int32, Char} -> String

        def initialize
          @x = ->(x : Int32, y : Char) { "a" }
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { proc_of([int32, char, string]) }
  end

  it "can assign NoReturn proc to other proc (#3032)" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      class Foo
        @x : -> Int32

        def initialize
          @x = ->{ LibC.exit }
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { proc_of(int32) }
  end

  it "*doesn't* merge Proc that returns Nil with another one that returns something else (#3655) (this was reverted)" do
    assert_type(%(
      a = ->(x : Int32) { 1 }
      b = ->(x : Int32) { nil }
      a || b
      )) { union_of proc_of(int32, int32), proc_of(int32, nil_type) }
  end

  it "*doesn't* merge Proc that returns NoReturn with another one that returns something else (#9971)" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      a = ->(x : Int32) { 1 }
      b = ->(x : Int32) { LibC.exit }
      a || b
      )) { union_of proc_of(int32, int32), proc_of(int32, no_return) }
  end

  it "merges return type" do
    assert_type(%(
      a = ->(x : Int32) { 1 }
      b = ->(x : Int32) { nil }
      (a || b).call(1)
      ), inject_primitives: true) { nilable int32 }
  end

  it "can assign proc that returns anything to proc that returns nil, with instance var (#3655)" do
    assert_type(%(
      class Foo
        @block : -> Nil

        def initialize
          @block = ->{ 1 }
        end

        def block
          @block
        end
      end

      Foo.new.block
      )) { proc_of(nil_type) }
  end

  it "can assign proc that returns anything to proc that returns nil, with class var (#3655)" do
    assert_type(%(
      module Moo
        @@block : -> Nil = ->{ nil }

        def self.block=(@@block)
        end

        def self.block
          @@block
        end
      end

      Moo.block = ->{ 1 }
      Moo.block
      )) { proc_of(nil_type) }
  end

  it "can assign proc that returns anything to proc that returns nil, with local var (#3655)" do
    assert_type(%(
      proc : -> Nil

      a = ->{ 1 }
      b = ->{ nil }
      proc = a || b

      proc
      )) { proc_of(nil_type) }
  end

  it "can pass proc that returns T as Void with named args (#7523)" do
    assert_type(%(
      def foo(proc : ->)
        proc
      end

      foo(proc: ->{ 1 })
      )) { proc_of(nil_type) }
  end

  it "errors when using macro as proc value (top-level) (#7465)" do
    ex = assert_error %(
      macro bar
      end

      ->bar
      ),
      "undefined method 'bar'"

    ex.to_s.should contain "'bar' exists as a macro, but macros can't be used in proc pointers"
  end

  it "errors when using macro as proc value (top-level with obj) (#7465)" do
    ex = assert_error %(
      class Foo
        macro bar
        end
      end

      ->Foo.bar
      ),
      "undefined method 'bar' for Foo.class"

    ex.to_s.should contain "'bar' exists as a macro, but macros can't be used in proc pointers"
  end

  it "errors when using macro as proc value (inside method) (#7465)" do
    ex = assert_error %(
      macro bar
      end

      def foo
        ->bar
      end

      foo
      ),
      "undefined method 'bar'\n\n"

    ex.to_s.should contain "'bar' exists as a macro, but macros can't be used in proc pointers"
  end

  it "virtualizes proc type (#6789)" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      class Capture(T)
        def initialize(@block : Foo -> T)
        end

        def block
          @block
        end
      end

      def capture(&block : Foo -> T) forall T
        Capture.new(block)
      end

      capture do |foo|
        Foo.new
      end.block
      )) { proc_of(types["Foo"].virtual_type!, types["Foo"].virtual_type!) }
  end

  it "virtualizes proc type with -> (#8730)" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      def foo(x)
        Foo.new
      end

      ->foo(Foo)
      )) { proc_of(types["Foo"].virtual_type!, types["Foo"].virtual_type!) }
  end

  it "can pass Proc(T) to Proc(Nil) in type restriction (#8964)" do
    assert_type(%(
      def foo(x : Proc(Nil))
        x
      end

      foo(->{ 1 })
      )) { proc_of nil_type }
  end

  it "can pass Proc(X, T) to Proc(X, Nil) in type restriction (#8964)" do
    assert_type(%(
      def foo(x : Proc(String, Nil))
        x
      end

      foo(->(x : String) { 1 })
      )) { proc_of string, nil_type }
  end

  it "casts to Proc(Nil) when specified in return type" do
    assert_type(%(
      def foo : Proc(Nil)
        ->{ 1 }
      end

      foo
      )) { proc_of nil_type }
  end

  it "can use @ivar as pointer syntax receiver (#9239)" do
    assert_type(%(
      class Foo
        def foo
          1
        end
      end

      class Bar
        @foo = Foo.new

        def foo
          ->@foo.foo
        end
      end

      Bar.new.foo
    )) { proc_of int32 }
  end

  it "can use @@cvar as pointer syntax receiver (#9239)" do
    assert_type(%(
      class Foo
        @@foo = new

        def self.foo
          ->@@foo.foo
        end

        def foo
          1
        end
      end

      Foo.foo
    )) { proc_of int32 }
  end

  it "doesn't cause upcast bug (#8428)" do
    assert_type(%(
      def foo
        if true
          begin
            ->{""}
          rescue
            return ->{}
          end
        end
      end

      foo
    )) { union_of proc_of(string), proc_of(nil_type), nil_type }
  end

  it "types Proc(*T, Void) as Proc(*T, Nil)" do
    assert_type(%(
      #{proc_new}

      Proc(Int32, Void).new { |x| x }
      )) { proc_of(int32, nil_type) }
  end
end

private def proc_new
  <<-CRYSTAL
  struct Proc
    def self.new(&block : self)
      block
    end
  end
  CRYSTAL
end

require "../../spec_helper"

describe "Block inference" do
  it "infer type of empty block body" do
    assert_type("
      def foo; yield; end

      foo do
      end
    ") { nil_type }
  end

  it "infer type of block body" do
    input = parse("
      def foo; yield; end

      foo do
        x = 1
      end
    ").as(Expressions)
    result = semantic input
    input.last.as(Call).block.not_nil!.body.type.should eq(result.program.int32)
  end

  it "infer type of block argument" do
    input = parse("
      def foo
        yield 1
      end

      foo do |x|
        1
      end
    ").as(Expressions)
    result = semantic input
    mod = result.program
    input.last.as(Call).block.not_nil!.args[0].type.should eq(mod.int32)
  end

  it "infer type of local variable" do
    assert_type("
      def foo
        yield 1
      end

      y = 'a'
      foo do |x|
        y = x
      end
      y
    ") { union_of(char, int32) }
  end

  it "infer type of yield" do
    assert_type("
      def foo
        yield
      end

      foo do
        1
      end
    ") { int32 }
  end

  it "infer type with union" do
    assert_type("
      require \"prelude\"
      a = [1] || [1.1]
      a.tap { |x| x }
    ") { union_of(array_of(int32), array_of(float64)) }
  end

  it "uses block arg, too many arguments" do
    assert_error %(
      def foo
        yield
      end

      foo do |x|
        x
      end
      ),
      "too many block arguments (given 1, expected maximum 0)"
  end

  it "yields with different types" do
    assert_type(%(
      def foo
        yield 1
        yield 'a'
      end

      foo do |x|
        x
      end
      )) { union_of(int32, char) }
  end

  it "break from block without value" do
    assert_type("
      def foo; yield; end

      foo do
        break
      end
    ") { nil_type }
  end

  it "break without value has nil type" do
    assert_type("
      def foo; yield; 1; end
      foo do
        break if false
      end
    ") { nilable int32 }
  end

  it "infers type of block before call" do
    result = assert_type("
      struct Int32
        def foo
          10.5
        end
      end

      class Foo(T)
        def initialize(x : T)
          @x = x
        end
      end

      def bar(&block : Int32 -> U) forall U
        Foo(U).new(yield 1)
      end

      bar { |x| x.foo }
      ") { generic_class "Foo", float64 }
    mod = result.program
    type = result.node.type.as(GenericClassInstanceType)
    type.type_vars["T"].type.should eq(mod.float64)
    type.instance_vars["@x"].type.should eq(mod.float64)
  end

  it "infers type of block before call taking other args free vars into account" do
    assert_type("
      class Foo(X)
        def initialize(x : X)
          @x = x
        end
      end

      def foo(x : U, &block: U -> T) forall T, U
        Foo(T).new(yield x)
      end

      a = foo(1) do |x|
        10.5
      end
      ") { generic_class "Foo", float64 }
  end

  it "reports error if yields a type that's not that one in the block specification" do
    assert_error "
      def foo(&block: Int32 -> )
        yield 10.5
      end

      foo {}
      ",
      "argument #1 of yield expected to be Int32, not Float64"
  end

  it "reports error if yields a type that's not that one in the block specification" do
    assert_error "
      def foo(&block: Int32 -> )
        yield (1 || 1.5)
      end

      foo {}
      ",
      "argument #1 of yield expected to be Int32, not (Float64 | Int32)"
  end

  it "reports error if yields a type that later changes and that's not that one in the block specification" do
    assert_error "
      def foo(&block: Int32 -> )
        a = 1
        while true
          yield a
          a = 1.5
        end
      end

      foo {}
      ",
      "argument #1 of yield expected to be Int32, not (Float64 | Int32)"
  end

  it "reports error if missing arguments to yield" do
    assert_error "
      def foo(&block: Int32, Int32 -> )
        yield 1
      end

      foo { |x| x }
      ",
      "wrong number of yield arguments (given 1, expected 2)"
  end

  it "reports error if block didn't return expected type" do
    assert_error "
      def foo(&block: Int32 -> Float64)
        yield 1
      end

      foo { 'a' }
      ",
      "expected block to return Float64, not Char"
  end

  it "reports error if block type doesn't match" do
    assert_error "
      def foo(&block: Int32 -> Float64)
        yield 1
      end

      foo { 1 || 1.5 }
      ",
      "expected block to return Float64, not (Float64 | Int32)"
  end

  it "reports error if block changes type" do
    assert_error "
      def foo(&block: Int32 -> Float64)
        yield 1
      end

      a = 10.5
      while true
        foo { a }
        a = 1
      end
      ",
      "type must be Float64"
  end

  it "reports error on method instantiate (#4543)" do
    assert_error %(
      class Foo
        @foo = 42

        def initialize(&block : -> Int32)
          @foo = yield
        end
      end

      Foo.new { 42u32 }
      ),
      "expected block to return Int32, not UInt32"
  end

  it "matches block arg return type" do
    assert_type("
      class Foo(T)
      end

      def foo(&block: Int32 -> Foo(T)) forall T
        yield 1
        Foo(T).new
      end

      foo { Foo(Float64).new }
      ") { generic_class "Foo", float64 }
  end

  it "infers type of block with generic type" do
    assert_type("
      class Foo(T)
      end

      def foo(&block: Foo(Int32) -> )
        yield Foo(Int32).new
      end

      foo do |x|
        10.5
      end
      ") { float64 }
  end

  it "infer type with self block arg" do
    assert_type("
      class Foo
        def foo(&block : self -> )
          yield self
        end
      end

      f = Foo.new
      a = nil
      f.foo do |x|
        a = x
      end
      a
      ") { nilable types["Foo"] }
  end

  it "error with self input type doesn't match" do
    assert_error "
      class Foo
        def foo(&block : self -> )
          yield 1
        end
      end

      f = Foo.new
      f.foo {}
      ",
      "argument #1 of yield expected to be Foo, not Int32"
  end

  it "error with self output type doesn't match" do
    assert_error "
      class Foo
        def foo(&block : Int32 -> self )
          yield 1
        end
      end

      f = Foo.new
      f.foo { 1 }
      ",
      "expected block to return Foo, not Int32"
  end

  it "errors when using local variable with block argument name" do
    assert_error "def foo; yield 1; end; foo { |a| }; a",
      "undefined local variable or method 'a'"
  end

  it "types empty block" do
    assert_type("
      def foo
        ret = yield
        ret
      end

      foo { }
    ") { nil_type }
  end

  it "preserves type filters in block" do
    assert_type("
      class Foo
        def bar
          'a'
        end
      end

      def foo
        yield 1
      end

      a = Foo.new || nil
      if a
        foo do |x|
          a.bar
        end
      else
        'b'
      end
      ") { char }
  end

  it "checks block type with virtual type" do
    assert_type("
      require \"prelude\"

      class Foo
      end

      class Bar < Foo
      end

      a = [] of Foo
      a << Bar.new

      a.map { |x| x.to_s }

      1
      ") { int32 }
  end

  it "maps block of union types to union types" do
    assert_type("
      require \"prelude\"

      class Foo1
      end

      class Bar1 < Foo1
      end

      class Foo2
      end

      class Bar2 < Foo2
      end

      a = [Foo1.new, Foo2.new, Bar1.new, Bar2.new]
      a.map { |x| x }
      ") { array_of(union_of(types["Foo1"].virtual_type, types["Foo2"].virtual_type)) }
  end

  it "does next from block without value" do
    assert_type("
      def foo; yield; end

      foo do
        next
      end
    ") { nil_type }
  end

  it "does next from block with value" do
    assert_type("
      def foo; yield; end

      foo do
        next 1
      end
    ") { int32 }
  end

  it "does next from block with value 2" do
    assert_type("
      def foo; yield; end

      foo do
        if 1 == 1
          next 1
        end
        false
      end
    ") { union_of(int32, bool) }
  end

  it "ignores block parameter if not used" do
    assert_type(%(
      def foo(&block)
        yield 1
      end

      foo do |x|
        x + 1
      end
      )) { int32 }
  end

  it "allows yielding multiple types when a union is expected" do
    assert_type(%(
      require "prelude"

      class Foo
        include Enumerable(Int32 | Float64)

        def each
          yield 1
          yield 1.5
        end
      end

      foo = Foo.new
      foo.map &.to_f
      )) { array_of(float64) }
  end

  it "allows initialize with yield (#224)" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize
          @x = yield 1
        end

        def x
          @x
        end
      end

      foo = Foo.new do |a|
        a + 1
      end
      foo.x
      )) { int32 }
  end

  it "passes #233: block with initialize with default args" do
    assert_type(%(
      class Foo
        def initialize(x = nil)
          yield
        end
      end

      Foo.new {}
      )) { types["Foo"] }
  end

  it "errors if declares def inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        def bar
        end
      end
      ),
      "can't declare def dynamically"
  end

  it "errors if declares macro inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        macro bar
        end
      end
      ),
      "can't declare macro dynamically"
  end

  it "errors if declares fun inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        fun bar : Int32
        end
      end
      ),
      "can't declare fun dynamically"
  end

  it "errors if declares class inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        class Foo
        end
      end
      ),
      "can't declare class dynamically"
  end

  it "errors if declares module inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        module Foo
        end
      end
      ),
      "can't declare module dynamically"
  end

  it "errors if declares lib inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        lib LibFoo
        end
      end
      ),
      "can't declare lib dynamically"
  end

  it "errors if declares alias inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        alias A = Int32
      end
      ),
      "can't declare alias dynamically"
  end

  it "errors if declares include inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        include Int32
      end
      ),
      "can't include dynamically"
  end

  it "errors if declares extend inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        extend Int32
      end
      ),
      "can't extend dynamically"
  end

  it "errors if declares enum inside block" do
    assert_error %(
      def foo
        yield
      end

      foo do
        enum Foo
          A
        end
      end
      ),
      "can't declare enum dynamically"
  end

  it "allows alias as block fun type" do
    assert_type(%(
      alias Alias = Int32 -> Int32

      def foo(&block : Alias)
        block.call(1)
      end

      foo do |x|
        x + 1
      end
      )) { int32 }
  end

  it "errors if alias is not a fun type" do
    assert_error %(
      alias Alias = Int32

      def foo(&block : Alias)
        block.call(1)
      end

      foo do |x|
        x + 1
      end
      ),
      "expected block type to be a function type, not Int32"
  end

  it "passes #262" do
    assert_type(%(
      require "prelude"

      h = {} of String => Int32
      h.map { true }
      )) { array_of(bool) }
  end

  it "allows invoking method on a object of a captured block with a type that was never instantiated" do
    assert_type(%(
      require "prelude"

      class Bar
        def initialize(@bar : NoReturn)
        end

        def bar
          @bar
        end
      end

      def foo(&block : Bar ->)
        block
      end

      def method(bar)
        bar.bar
      end

      foo do |bar|
        method(bar).baz
      end
      )) { proc_of(types["Bar"], void) }
  end

  it "types bug with yield not_nil! that is never not nil" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      def foo
        key = nil
        if 1 == 2
          yield LibC.exit
        end
        yield 1
      end

      extra = nil

      foo do |key|
        if 1 == 1
          extra = 1
          extra + key
        end
      end

      extra
      )) { nilable(int32) }
  end

  it "ignores void return type (#427)" do
    assert_type(%(
      lib Fake
        fun foo(func : -> Void)
      end

      def foo(&block : -> Void)
        Fake.foo block
      end

      foo do
        1
      end
      )) { nil_type }
  end

  it "ignores void return type (2) (#427)" do
    assert_type(%(
      def foo(&block : Int32 -> Void)
        yield 1
      end

      foo do
        1
      end
      )) { int32 }
  end

  it "ignores void return type (3) (#427)" do
    assert_type(%(
      alias Alias = Int32 -> Void

      def foo(&block : Alias)
        yield 1
      end

      foo do
        1
      end
      )) { int32 }
  end

  it "ignores void return type (4)" do
    assert_type(%(
      alias Alias = Void

      def foo(&block : -> Alias)
        yield
      end

      foo do
        1
      end
      )) { int32 }
  end

  it "uses block return type as return type, even if can't infer block type" do
    assert_type(%(
      class Foo
        def initialize(@foo : Int32)
        end

        def foo
          @foo
        end
      end

      def bar(&block : -> Int32)
        block
      end

      f = ->(x : Foo) {
        bar { x.foo }
      }

      foo = Foo.new(100)
      block = f.call(foo)
      block.call
      )) { int32 }
  end

  it "uses block var with same name as local var" do
    assert_type(%(
      def foo
        yield true
      end

      a = 1
      foo do |a|
        a
      end
      a
      )) { int32 }
  end

  it "types recursive hash assignment" do
    assert_type(%(
      require "prelude"

      class Hash
        def map
          ary = Array(typeof(yield first_key, first_value)).new(@size)
          each do |k, v|
            ary.push yield k, v
          end
          ary
        end
      end

      hash = {} of Int32 => Int32
      z = hash.map {|key| key + 1 }
      hash[1] = z.size
      z
      )) { array_of int32 }
  end

  it "errors if invoking new with block when no initialize is defined" do
    assert_error %(
      class Foo
      end

      Foo.new { }
      ),
      "'Foo.new' is not expected to be invoked with a block, but a block was given"
  end

  it "recalculates call that uses block arg output as free var" do
    assert_type(%(
      def foo(&block : Int32 -> U) forall U
        block
        U
      end

      class Foo
        def initialize
          @x = 1
        end

        def x=(@x : Char)
        end

        def bar
          foo do |x|
            @x
          end
        end
      end

      z = Foo.new.bar
      Foo.new.x = 'a'
      z
      )) { union_of(char, int32).metaclass }
  end

  it "finds type inside module in block" do
    assert_type(%(
      module Moo
        class Foo
        end

        class Bar
          def initialize(&block : Int32 -> U) forall U
            block
          end
        end
      end

      z = nil
      module Moo
        z = Bar.new { Foo.new }
      end
      z
      )) { types["Moo"].types["Bar"] }
  end

  it "passes &->f" do
    assert_type(%(
      def foo
      end

      def bar(&block)
        yield
        1
      end

      bar &->foo
      )) { int32 }
  end

  it "errors if declares class inside captured block" do
    assert_error %(
      def foo(&block)
        block.call
      end

      foo do
        class B
        end
      end
      ),
      "can't declare class dynamically"
  end

  it "doesn't assign block variable type to last value (#694)" do
    assert_type(%(
      def foo
        yield 1
      end

      z = 1
      foo do |x|
        z = x
        x = "a"
      end
      z
      )) { int32 }
  end

  it "errors if yields from top level" do
    assert_error %(
      yield
      ),
      "can't use `yield` outside a method"
  end

  it "errors on recursive yield" do
    assert_error %(
      def foo
        yield

        foo do
        end
      end

      foo {}
      ),
      "recursive block expansion"
  end

  it "binds to proc, not only to its body (#1796)" do
    assert_type(%(
      def yielder(&block : Int32 -> U) forall U
        yield 1
        U
      end

      yielder { next 'a' if true; 1 }
      )) { union_of(int32, char).metaclass }
  end

  it "binds block return type free variable even if there are no block arguments (#1797)" do
    assert_type(%(
      def yielder(&block : -> U) forall U
        yield
        U
      end

      yielder { 1 }
      )) { int32.metaclass }
  end

  it "returns from proc literal" do
    assert_type(%(
      foo = ->{
        if 1 == 1
          return 1
        end

        1.5
      }

      foo.call
      )) { union_of int32, float64 }
  end

  it "errors if returns from captured block" do
    assert_error %(
      def foo(&block)
        block
      end

      def bar
        foo do
          return
        end
      end

      bar
      ),
      "can't return from captured block, use next"
  end

  it "errors if breaks from captured block" do
    assert_error %(
      def foo(&block)
        block
      end

      def bar
        foo do
          break
        end
      end

      bar
      ),
      "can't break from captured block"
  end

  it "errors if doing next in proc literal" do
    assert_error %(
      foo = ->{
        next
      }
      foo.call
      ),
      "Invalid next"
  end

  it "does next from captured block" do
    assert_type(%(
      def foo(&block : -> T) forall T
        block
      end

      f = foo do
        if 1 == 1
          next 1
        end

        next 1.5
      end

      f.call
      )) { union_of int32, float64 }
  end

  it "sets captured block type to that of restriction" do
    assert_type(%(
      def foo(&block : -> Int32 | String)
        block
      end

      foo { 1 }
      )) { proc_of(union_of(int32, string)) }
  end

  it "sets captured block type to that of restriction with alias" do
    assert_type(%(
      alias Alias = -> Int32 | String
      def foo(&block : Alias)
        block
      end

      foo { 1 }
      )) { proc_of(union_of(int32, string)) }
  end

  it "matches block with generic type and free var" do
    assert_type(%(
      class Foo(T)
      end

      def foo(&block : -> Foo(T)) forall T
        block
        T
      end

      foo { Foo(Int32).new }
      )) { int32.metaclass }
  end

  it "doesn't mix local var with block var, using break (#2314)" do
    assert_type(%(
      def foo
        yield 1
      end

      x = true
      foo do |x|
        break
      end
      x
      )) { bool }
  end

  it "doesn't mix local var with block var, using next (#2314)" do
    assert_type(%(
      def foo
        yield 1
      end

      x = true
      foo do |x|
        next
      end
      x
      )) { bool }
  end

  ["Object", "Bar | Object", "(Object ->)", "( -> Object)"].each do |string|
    it "errors if using #{string} as block return type (#2358)" do
      assert_error %(
        class Foo(T)
        end

        class Bar
        end

        def capture(&block : -> #{string})
          block
        end

        capture { 1 }
        ),
        "use a more specific type"
    end
  end

  it "yields splat" do
    assert_type(%(
      def foo
        tup = {1, 'a'}
        yield *tup
      end

      foo do |x, y|
        {y, x}
      end
      )) { tuple_of([char, int32]) }
  end

  it "yields splat and non splat" do
    assert_type(%(
      def foo
        tup = {1, 'a'}
        yield *tup

        yield true, nil
      end

      foo do |x, y|
        {y, x}
      end
      )) { tuple_of([nilable(char), union_of(int32, bool)]) }
  end

  it "uses splat in block argument" do
    assert_type(%(
      def foo
        yield 1, 'a'
      end

      foo do |*args|
        args
      end
      )) { tuple_of([int32, char]) }
  end

  it "uses splat in block argument, many args" do
    assert_type(%(
      def foo
        yield 1, 'a', true, nil, 1.5, "hello"
      end

      foo do |x, *y, z, w|
        {x, y, z, w}
      end
      )) { tuple_of([int32, tuple_of([char, bool, nil_type]), float64, string]) }
  end

  it "uses splat in block argument, but not enough yield expressions" do
    assert_error %(
      def foo
        yield 1
      end

      foo do |x, y, z, *w|
        {x, y, z, w}
      end
      ),
      "too many block arguments (given 3+, expected maximum 1+)"
  end

  it "errors if splat argument becomes a union" do
    assert_error %(
      def foo
        yield 1
        yield 1, 2
      end

      foo do |*args|
      end
      ),
      "block splat argument must be a tuple type"
  end

  it "auto-unpacks tuple" do
    assert_type(%(
      def foo
        tup = {1, 'a'}
        yield tup
      end

      foo do |x, y|
        {x, y}
      end
      )) { tuple_of([int32, char]) }
  end

  it "auto-unpacks tuple, less than max" do
    assert_type(%(
      def foo
        tup = {1, 'a', true}
        yield tup
      end

      foo do |x, y|
        {x, y}
      end
      )) { tuple_of([int32, char]) }
  end

  it "auto-unpacks with block arg type" do
    assert_type(%(
      def foo(&block : {Int32, Int32} -> _)
        yield({1, 2})
      end

      foo do |x, y|
        x + y
      end
      )) { int32 }
  end

  it "doesn't auto-unpacks tuple, more args" do
    assert_error %(
      def foo
        tup = {1, 'a'}
        yield tup, true
      end

      foo do |x, y, z|
      end
      ),
      "too many block arguments (given 3, expected maximum 2)"
  end

  it "auto-unpacks tuple, too many args" do
    assert_error %(
      def foo
        tup = {1, 'a'}
        yield tup
      end

      foo do |x, y, z|
      end
      ),
      "too many block arguments (given 3, expected maximum 2)"
  end

  it "doesn't crash on #2531" do
    run(%(
      def foo
        yield
      end

      value = true ? 1 : nil
      foo do
        value ? nil : nil
      end
      value ? 10 : 20
      )).to_i.should eq(10)
  end

  it "yields in overload, matches type" do
    assert_type(%(
      struct Int
        def foo(&block : self ->)
          yield self
        end
      end

      (1 || 1_i64).foo do |x|
        x
      end
      )) { union_of(int32, int64) }
  end

  it "uses free var in return type in captured block" do
    assert_type(%(
      class U
      end

      def foo(&block : -> U) forall U
        block
        U
      end

      foo { 1 }
      )) { int32.metaclass }
  end

  it "uses free var in return type with tuple type" do
    assert_type(%(
      class T; end

      class U; end

      class Foo(T)
        def initialize(@x : T)
        end

        def foo(&block : T -> U) forall U
          {yield(@x), U}
        end
      end

      Foo.new(1).foo { |x| {x, x} }
      )) { tuple_of([tuple_of([int32, int32]), tuple_of([int32, int32]).metaclass]) }
  end

  it "correctly types unpacked tuple block arg after block (#3339)" do
    assert_type(%(
      def foo
        yield({""})
      end

      i = 1
      foo do |(i)|

      end
      i
      ), inject_primitives: false) { int32 }
  end
end

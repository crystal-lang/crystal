require "../../spec_helper"

describe "Code gen: debug" do
  it "codegens abstract struct (#3578)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      abstract struct Base
      end

      struct Foo < Base
      end

      struct Bar < Base
      end

      x = Foo.new || Bar.new
      CRYSTAL
  end

  it "codegens lib union (#7335)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      lib Foo
        union Bar
          a : Int32
          b : Int16
          c : Int8
        end
      end

      x = Foo::Bar.new
      CRYSTAL
  end

  it "codegens extern union (#7335)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      @[Extern(union: true)]
      struct Foo
        @a = uninitialized Int32
        @b = uninitialized Int16
        @c = uninitialized Int8
      end

      x = Foo.new
      CRYSTAL
  end

  it "inlines instance var access through getter in debug mode" do
    run(<<-CRYSTAL, debug: Crystal::Debug::All, filename: "foo.cr").to_i.should eq(2)
      struct Bar
        @x = 1

        def set
          @x = 2
        end

        def x
          @x
        end
      end

      class Foo
        @bar = Bar.new

        def set
          bar.set
        end

        def bar
          @bar
        end
      end

      foo = Foo.new
      foo.set
      foo.bar.x
      CRYSTAL
  end

  it "codegens correct debug info for untyped expression (#4007 and #4008)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      require "prelude"

      int = 3
      case int
      when 0
          puts 0
      when 1, 2, Int32
          puts "1 | 2 | Int32"
      else
          puts int
      end
      CRYSTAL
  end

  it "codegens correct debug info for new with custom allocate (#3945)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      class Foo
        def initialize
        end

        def self.allocate
          Pointer(UInt8).malloc(1_u64).as(self)
        end
      end

      Foo.new
      CRYSTAL
  end

  it "correctly restores debug location after fun change (#4254)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      require "prelude"

      class Foo
        def self.one
          TWO.two { three }
          self
        end

        def self.three
          1 + 2
        end

        def two(&block)
          block
        end
      end

      ONE = Foo.one
      TWO = Foo.new

      ONE.three
      CRYSTAL
  end

  it "has correct debug location after constant initialization in call with block (#4719)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      require "prelude"

      fun __crystal_malloc_atomic(size : UInt32) : Void*
        x = uninitialized Void*
        x
      end

      class Foo
      end

      class Bar
        def initialize
          yield
        end
      end

      A = Foo.new

      Bar.new { }

      A
      CRYSTAL
  end

  it "has debug info in closure inside if (#5593)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      def foo
        if true && true
          yield 1
        end
      end

      def bar(&block)
        block
      end

      foo do |i|
        bar do
          i
        end
      end
      CRYSTAL
  end

  it "doesn't emit incorrect debug info for closured self" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      def foo(&block : Int32 ->)
        block.call(1)
      end

      class Foo
        def bar
          foo do
            self
          end
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "doesn't emit debug info for unused variable declarations (#9882)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      x : Int32
      CRYSTAL
  end

  it "emits global debug info for constants" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      struct Bar
        def initialize(@x : Int32)
        end
      end

      A = Bar.new(41)

      v1 = A
      v1
      CRYSTAL

    str = mod.to_s
    str.should contain("DIGlobalVariable(name: \"A\", linkageName: \"A\",")
    str.should contain(%(~A:const_init))
  end

  it "emits global debug info once for constants read before assignment" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      require "prelude"

      struct Bar
        def initialize(@x : Int32)
        end
      end

      A
      A = Bar.new(41)
      CRYSTAL

    str = mod.to_s
    str.scan(%r{DIGlobalVariable\(name: "A", linkageName: "A",}).size.should eq(1)
    str.should contain(%(~A:const_init))
  end

  it "keeps literal constants inlined in debug mode" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      A = 1

      def foo
        A
      end

      foo
      CRYSTAL

    str = mod.to_s
    str.should_not match(/^@A =/)
    str.should contain("ret i32 1")
  end

  it "emits global debug info for class vars" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      class Foo
        @@x = "world"

        def self.x
          @@x
        end
      end

      Foo.x
      CRYSTAL

    str = mod.to_s
    str.should match(/@"Foo::x" = global (?:ptr|%String\*) null, !dbg !/)
    str.should contain("DIGlobalVariable(name: \"Foo::x\", linkageName: \"Foo::x\",")
  end

  it "stores and restores debug location after jumping to main (#6920)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      require "prelude"

      Module.method

      module Module
        def self.value
          1 &+ 2
        end

        @@x : Int32 = value

        def self.method
          @@x
        end
      end
      CRYSTAL
  end

  it "stores and restores debug location after jumping to main (2)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      module Foo
        @@x : Int32 = begin
          y = 1
        end

        def self.x
          @@x
        end
      end

      Foo.x
      CRYSTAL
  end

  it "stores and restores debug location after jumping to main (3)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      def raise(exception)
        x = uninitialized NoReturn
        x
      end

      lib LibFoo
        $foo : ->
      end

      LibFoo.foo = ->{ }
      CRYSTAL
  end

  it "doesn't fail on constant read calls (#11416)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      require "prelude"

      class Foo
        def foo
        end
      end

      def a_foo
        Foo.new
      end

      THE_FOO.foo

      THE_FOO = a_foo
      CRYSTAL
  end

  it "doesn't fail on splat expansions inside array-like literals" do
    run(<<-CRYSTAL, debug: Crystal::Debug::All).to_i.should eq(123)
      require "prelude"

      class Foo
        def each
          yield 1
          yield 2
          yield 3
        end
      end

      class Bar
        @bar = 0

        def <<(value)
          @bar = @bar &* 10 &+ value
        end

        def bar
          @bar
        end
      end

      x = Foo.new
      y = Bar{*x}
      y.bar
      CRYSTAL
  end

  it "codegens proc debug info" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      x = ->(n : Int32) { n &+ 1 }
      y : Proc(Int32, Int32)? = ->(n : Int32) { n &+ 2 }
      captured = 40
      z = ->(n : Int32) { captured &+ n }
      {x, y, z}
      CRYSTAL
  end

  it "attributes branches to their body, and merges and def epilogue to no line" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All, single_module: true)
      lib LibC
        fun exit(status : Int32) : NoReturn
      end

      struct Int32
        def ===(other : Int32)
          self == other
        end
      end

      class Foo
        @status = 1

        def foo(value : Int32)
          case value
          when 1
            10
          when 2
            20
          else
            LibC.exit(@status)
          end
        end
      end

      Foo.new.foo(1)
      CRYSTAL

    str = mod.to_s
    # `Foo#foo`, found by its parameters because symbol names are mangled on Windows
    foo = str[/^define [^\n]+ %self, i32 %value\).+?^}/m]
    debug_line_of(str, foo, / = phi /).should eq(0)
    debug_line_of(str, foo, /^\s+ret /).should eq(0)
    debug_line_of(str, foo, /^\s+br label %exit, /).should eq(17)
    debug_line_of(str, foo, /^\s+br label %exit3, /).should eq(19)
    debug_line_of(str, foo, /getelementptr inbounds %Foo,/).should eq(21)
    debug_line_of(str, foo, /call void @exit/).should eq(21)
  end

  it "attributes the type checks of a dispatch to the call" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All, single_module: true)
      class Foo
        def bar
          1
        end
      end

      class Bar
        def bar
          2
        end
      end

      class Baz
        @value : Foo | Bar = Foo.new

        def baz(index : Int32)
          @value.bar
        end
      end

      Baz.new.baz(1)
      CRYSTAL

    str = mod.to_s
    # `Baz#baz`, found by its parameters because symbol names are mangled on Windows
    baz = str[/^define [^\n]+ %self, i32 %index\).+?^}/m]
    debug_line_of(str, baz, /icmp eq i32/).should eq(17)
  end

  it "attributes primitive calls, casts and type checks to their own line" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All, single_module: true)
      fun __crystal_raise_cast_failed(from_type : Void*, to_type : Void*, location : Void*) : NoReturn
        while true
        end
      end

      class Foo
      end

      class Bar < Foo
      end

      def add(add_value : Int32)
        add_value &+ 1
      end

      def cast(cast_value : Foo)
        cast_value.as(Bar)
      end

      def nilable_cast(nilable_cast_value : Foo)
        nilable_cast_value.as?(Bar)
      end

      def type_check(type_check_value : Foo)
        type_check_value.is_a?(Bar)
      end

      add(1)
      cast(Bar.new.as(Foo))
      nilable_cast(Bar.new.as(Foo))
      type_check(Bar.new.as(Foo))
      CRYSTAL

    str = mod.to_s
    # Functions are found by their parameters because symbol names are mangled on Windows
    add = str[/^define [^\n]+ %add_value\).+?^}/m]
    debug_line_of(str, add, / = add i32 /).should eq(13)
    cast = str[/^define [^\n]+ %cast_value\).+?^}/m]
    debug_line_of(str, cast, /icmp eq i32/).should eq(17)
    nilable_cast = str[/^define [^\n]+ %nilable_cast_value\).+?^}/m]
    debug_line_of(str, nilable_cast, /icmp eq i32/).should eq(21)
    type_check = str[/^define [^\n]+ %type_check_value\).+?^}/m]
    debug_line_of(str, type_check, /icmp eq i32/).should eq(25)
  end

  {% unless LibLLVM::IS_LT_210 %}
    it "supports 128-bit enumerators" do
      codegen(<<-CRYSTAL, debug: Crystal::Debug::All).to_s.should contain(%(!DIEnumerator(name: "X", value: 1002003004005006007008009)))
        enum Foo : Int128
          X = 1002003004005006007008009_i128
        end

        x = Foo::X
        CRYSTAL
    end
  {% end %}

  it "doesn't fail if no top-level code follows discarded class var initializer (#15970)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      module Foo
        @@x = 1
      end
      CRYSTAL
  end

  it "doesn't fail if class var initializer is followed by metaclass (#15970)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      module Foo
        @@x = 1
      end

      Int32
      CRYSTAL
  end

  it "emits debug location for inlined calls and primitives (#15360)" do
    mod = codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      class Foo
        @x = 1

        def x
          @x
        end
      end

      foo = Foo.new
      a = foo.x
      b = a &* 2
      CRYSTAL

    str = mod.to_s
    main = str[/^define [^\n]+ @__crystal_main\(.+?^}/m]
    debug_line_of(str, main, /getelementptr inbounds %Foo,/).should eq(10)
    debug_line_of(str, main, / = mul i32 /).should eq(11)
  end

  it "doesn't fail if Proc self is closured (#16382)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      struct Proc
        def partial
          -> do
            self
          end
        end
      end

      -> { }.partial.call
      CRYSTAL
  end
end

# Returns the line number of the debug location attached to the first instruction in *function* matching *pattern*.
# *ir* is the whole module.
private def debug_line_of(ir, function, pattern)
  instruction = function.each_line.find!(&.matches?(pattern))
  dbg_id = instruction[/!dbg (![0-9]+)/, 1]
  ir[/^#{dbg_id} = !DILocation\(line: ([0-9]+)/m, 1].to_i
end

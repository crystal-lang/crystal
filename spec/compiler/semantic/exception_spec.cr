require "../../spec_helper"

describe "Semantic: exception" do
  it "type is union of main and rescue blocks" do
    assert_type("
      begin
        1
      rescue
        'a'
      end
    ") { union_of(int32, char) }
  end

  it "type union with empty main block" do
    assert_type("
      begin
      rescue
        1
      end
    ") { nilable int32 }
  end

  it "type union with empty rescue block" do
    assert_type("
      begin
        1
      rescue
      end
    ") { nilable int32 }
  end

  it "type for exception handler for explicit types" do
    assert_type("
      require \"prelude\"

      class MyEx < Exception
      end

      begin
        raise MyEx.new
      rescue MyEx
        1
      end
    ") { int32 }
  end

  it "marks method calling method that raises as raises" do
    result = assert_type("
      lib LibFoo
        @[Raises]
        fun some_fun : Int32
      end

      def foo
        LibFoo.some_fun
      end

      foo
    ") { int32 }
    mod = result.program
    a_def = mod.lookup_first_def("foo", false)
    def_instance = mod.lookup_def_instance DefInstanceKey.new(a_def.object_id, [] of Type, nil, nil)
    def_instance.not_nil!.raises?.should be_true
  end

  it "marks method calling lib fun that raises as raises" do
    result = assert_type("
      @[Raises]
      fun some_fun : Int32; 1; end

      def foo
        some_fun
      end

      foo
    ") { int32 }
    mod = result.program
    a_def = mod.lookup_first_def("foo", false)
    def_instance = mod.lookup_def_instance DefInstanceKey.new(a_def.object_id, [] of Type, nil, nil)
    def_instance.not_nil!.raises?.should be_true
  end

  it "types exception var with no types" do
    assert_type("
      a = nil
      begin
      rescue ex
        a = ex
      end
      a
    ") { union_of(nil_type, exception.virtual_type) }
  end

  it "types exception with type" do
    assert_type("
      class Ex < Exception
      end

      a = nil
      begin
      rescue ex : Ex
        a = ex
      end
      a
    ") { union_of(nil_type, types["Ex"].virtual_type) }
  end

  it "types var as not nil if defined inside begin and defined inside rescue" do
    assert_type("
      begin
        a = 1
      rescue
        a = 2
      end
      a
      ") { int32 }
  end

  it "types var as nilable if previously nilable (1)" do
    assert_type("
      if 1 == 2
        a = 1
      end

      begin
        a = 2
      rescue
      end
      a
      ", inject_primitives: true) { nilable int32 }
  end

  it "types var as nilable if previously nilable (2)" do
    assert_type("
      if 1 == 2
        a = 1
      end

      begin
      rescue
        a = 2
      end
      a
      ", inject_primitives: true) { nilable int32 }
  end

  it "errors if caught exception is not a subclass of Exception" do
    assert_error "begin; rescue ex : Int32; end", "Int32 is not a subclass of Exception"
  end

  it "errors if caught exception is not a subclass of Exception without var" do
    assert_error "begin; rescue Int32; end", "Int32 is not a subclass of Exception"
  end

  assert_syntax_error "begin; rescue ex; rescue ex : Foo; end; ex",
    "specific rescue must come before catch-all rescue"

  assert_syntax_error "begin; rescue ex; rescue; end; ex",
    "catch-all rescue can only be specified once"

  assert_syntax_error "begin; else; 1; end",
    "'else' is useless without 'rescue'"

  it "types code with abstract exception that delegates method" do
    assert_type(%(
      require "prelude"

      class Object
        def foo
          bar(1)
        end

        def bar(x)
          1
        end
      end

      class SomeException < ::Exception
      end

      abstract class FooException < ::Exception
        def bar(io)
          bar2(nil, io)
        end
      end

      begin
      rescue ex
        ex.foo
      end

      1
      )) { int32 }
  end

  it "transform nodes in else block" do
    assert_type(%(
      begin
      rescue
      else
        1 || nil
      end
    )) { nilable int32 }
  end

  it "types var as nilable inside ensure (1)" do
    result = assert_type(%(
      require "prelude"

      n = nil
      begin
        raise "hey"
        n = 3
      ensure
        p n
      end
      n
      )) { int32 }
    mod = result.program
    eh = result.node.as(Expressions).expressions[-2]
    call_p_n = eh.as(ExceptionHandler).ensure.not_nil!.as(Call)
    call_p_n.args.first.type.should eq(mod.nilable(mod.int32))
  end

  it "types var as nilable inside ensure (2)" do
    result = assert_type(%(
      require "prelude"

      begin
        raise "hey"
        n = 3
      ensure
        p n
      end
      n
      )) { int32 }
    mod = result.program
    eh = result.node.as(Expressions).expressions[-2]
    call_p_n = eh.as(ExceptionHandler).ensure.not_nil!.as(Call)
    call_p_n.args.first.type.should eq(mod.nilable(mod.int32))
  end

  it "marks fun as raises" do
    result = assert_type(%(
      @[Raises]
      fun foo : Int32; 1; end
      foo
      )) { int32 }
    mod = result.program
    a_def = mod.lookup_first_def("foo", false)
    a_def.not_nil!.raises?.should be_true
  end

  it "marks def as raises" do
    result = assert_type(%(
      @[Raises]
      def foo
        1
      end

      foo
      )) { int32 }
    mod = result.program
    a_def = mod.lookup_first_def("foo", false)
    a_def.not_nil!.raises?.should be_true
  end

  it "marks method that calls another method that raises as raises, recursively" do
    result = assert_type(%(
      @[Raises]
      def foo
        1
      end

      def bar
        foo
      end

      def baz
        bar
      end

      foo
      bar
      baz
      )) { int32 }
    call = result.node.as(Expressions).expressions.last.as(Call)
    call.target_defs.not_nil!.first.raises?.should be_true
  end

  it "marks proc literal as raises" do
    result = assert_type("->{ 1 }.call", inject_primitives: true) { int32 }
    call = result.node.as(Expressions).last.as(Call)
    call.target_def.raises?.should be_true
  end

  it "shadows local variable (1)" do
    assert_type(%(
      require "prelude"

      a = 1
      begin
        raise "OH NO"
      rescue a
        a
      end
      a
      )) { union_of(int32, types["Exception"].virtual_type) }
  end

  it "remains nilable after rescue" do
    assert_type(%(
      require "prelude"

      begin
        raise "OH NO"
      rescue a
        a
      end
      a
      )) { nilable types["Exception"].virtual_type }
  end

  it "doesn't consider vars as nilable inside else (#610)" do
    assert_type(%(
      require "prelude"

      x = 1
      begin
        a = 1
      rescue
      else
        x = a
      end
      x
      )) { int32 }
  end

  it "types instance variable as nilable if assigned inside an exception handler (#1845)" do
    assert_error %(
      class Foo
        def initialize
          begin
            @bar = 1
          rescue
          end
        end

        def bar
          @bar
        end
      end

      foo = Foo.new
      foo.bar
      ),
      "instance variable '@bar' of Foo must be Int32, not Nil"
  end

  it "doesn't type instance variable as nilable if assigned inside an exception handler after being assigned" do
    assert_type(%(
      class Foo
        def initialize
          @bar = 1
          begin
            @bar = 1
          rescue
          end
        end

        def bar
          @bar
        end
      end

      foo = Foo.new
      foo.bar
      )) { int32 }
  end

  it "correctly types #1988" do
    assert_type(%(
      begin
        x = 1
      rescue
      end

      if x.is_a?(Int32)
        x
      else
        x
      end
      )) { nilable int32 }
  end

  it "doesn't crash on break inside rescue, in while (#2441)" do
    assert_type(%(
      while true
        begin
        rescue ex
          break
        end
      end

      ex
      )) { nilable types["Exception"].virtual_type }
  end

  it "types var assignment inside block inside exception handler (#3324)" do
    assert_type(%(
      def foo
        yield
      end

      var = 1
      begin
        foo do
          var = "foo"
        end
      rescue
      end
      var
      )) { union_of(int32, string) }
  end

  it "marks instance variable as nilable if assigned inside rescue inside initialize" do
    assert_error %(
      require "prelude"

      class Coco < Exception
        def initialize(@x : Foo)
        end
      end

      class Foo
        def initialize
          @x = 1
        rescue
          raise Coco.new(self)
        end
      end

      Foo.new
      ),
      "instance variable '@x' of Foo must be Int32, not Nil"
  end

  it "assigns var inside ensure (1) (#3919)" do
    assert_type(%(
      begin
      ensure
        a = 1
      end
      a
      )) { int32 }
  end

  it "assigns var inside ensure (2) (#3919)" do
    assert_type(%(
      a = true
      begin
      ensure
        a = 1
      end
      a
      )) { int32 }
  end

  it "doesn't infect type to variable before handler (#4002)" do
    assert_type(%(
      a = 1
      b = a
      begin
        a = 'a'
      rescue
      end
      b
      )) { int32 }
  end

  it "detects reading nil-if-read variable after exception handler (#4723)" do
    result = assert_type(%(
      if true
        foo = 42
      end

      # Now, `@vars["foo"].type` is `Int32` and `@vars["foo"].nil_if_read?` is `true`.

      begin
      rescue
      end

      # If `@vars["foo"].nil_if_read?` is `true`, `foo` on `program.vars`
      # binds to `nil` node, so `program.vars["foo"].type` becomes `Int32 | Nil`.
      # However if not (it is BUG), `program.vars["foo"].type` is `Int32`
      # even though the type of the node `foo` is `Int32 | Nil`.
      foo
    )) { nilable int32 }
    program = result.program
    program.vars["foo"].type.should be(program.nilable program.int32)
  end

  it "can't return from ensure (#4470)" do
    assert_error(%(
      def foo
        return 1
      ensure
        return 2
      end

      foo
    ), "can't return from ensure")
  end

  it "can't return from block inside ensure (#4470)" do
    assert_error(%(
      def once
        yield
      end

      def foo
        return 1
      ensure
        once do
          return 2
        end
      end

      foo
    ), "can't return from ensure")
  end

  it "can't return from while inside ensure (#4470)" do
    assert_error(%(
      def foo
        return 1
      ensure
        while true
          return 2
        end
      end

      foo
    ), "can't return from ensure")
  end

  it "can't use break inside while inside ensure (#4470)" do
    assert_error(%(
      while true
        begin
          break
        ensure
          break
        end
      end
    ), "can't use break inside ensure")
  end

  it "can use break inside while inside ensure (#4470)" do
    assert_type(%(
      while true
        begin
          break
        ensure
          while true
            break
          end
        end
      end
    )) { nil_type }
  end

  it "can't use break inside block inside ensure (#4470)" do
    assert_error(%(
      def loop
        while true
          yield
        end
      end

      loop do
        begin
          break
        ensure
          break
        end
      end
    ), "can't use break inside ensure")
  end

  it "can use break inside block inside ensure (#4470)" do
    assert_type(%(
      def loop
        while true
          yield
        end
      end

      loop do
        begin
          break
        ensure
          loop do
            break
          end
        end
      end
    )) { nil_type }
  end

  it "can't use next inside while inside ensure (#4470)" do
    assert_error(%(
      while true
        begin
          break
        ensure
          next
        end
      end
    ), "can't use next inside ensure")
  end

  it "can't use next inside block inside ensure (#4470)" do
    assert_error(%(
      def loop
        while true
          yield
        end
      end

      loop do
        begin
          break
        ensure
          next
        end
      end
    ), "can't use next inside ensure")
  end

  it "can use next inside while inside ensure (#4470)" do
    assert_type(%(
      while true
        begin
          break
        ensure
          a = 0
          while a < 1
            a = 1
            next
          end
        end
      end
    ), inject_primitives: true) { nil_type }
  end

  it "can use next inside block inside ensure (#4470)" do
    assert_type(%(
      def loop
        while true
          yield
        end
      end

      def once
        yield
      end

      loop do
        begin
          break
        ensure
          once do
            next
          end
        end
      end
    )) { nil_type }
  end

  it "correctly types variables inside conditional inside exception handler with no-return rescue (#8012)" do
    assert_type(%(
      def foo
        begin
          x = 99 if false
        rescue
          return 10
        end

        x
      end

      foo
    )) { nilable int32 }
  end

  it "gets a non-nilable type if all rescue are unreachable (#8751)" do
    assert_no_errors <<-CRYSTAL, inject_primitives: true
      while true
        begin
          foo = 1
          break
        rescue
          foo
          break
        end

        foo &+ 2
      end
      CRYSTAL
  end

  it "correctly types variable assigned inside nested exception handler (#9769)" do
    assert_type(%(
      int = 1
      begin
        begin
          int = "a"
        rescue
        end
      rescue
      end
      int
    )) { union_of(int32, string) }
  end

  it "types a var after begin rescue as having all possible types and nil in begin if read (2)" do
    assert_type(%(
      begin
        a = 2
        a = 'a'
      rescue
      end
      a
      )) { union_of [int32, char, nil_type] of Type }
  end

  it "types a var after begin rescue as having all possible types in begin and rescue" do
    assert_type(%(
      a = 1.5
      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        a = false
      end
      a
      )) { union_of [float64, int32, char, string, bool] of Type }
  end

  it "types a var after begin rescue as having all possible types in begin and rescue (2)" do
    assert_type(%(
      b = 2
      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        b = a
      end
      b
      )) { union_of [int32, char, string, nil_type] of Type }
  end

  it "types a var after begin rescue with no-return in rescue" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        LibC.exit
      end
      a
      )) { string }
  end

  it "types a var after rescue as being nilable" do
    assert_type(%(
      begin
      rescue
        a = 1
      end
      a
      )) { nilable int32 }
  end
end

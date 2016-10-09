require "../../spec_helper"

describe "Semantic: closure" do
  it "gives error when doing yield inside proc literal" do
    assert_error "-> { yield }", "can't use `yield` outside a method"
  end

  it "gives error when doing yield inside proc literal" do
    assert_error "def foo; -> { yield }; end; foo {}", "can't use `yield` inside a proc literal or captured block"
  end

  it "marks variable as closured in program" do
    result = assert_type("x = 1; -> { x }; x") { int32 }
    program = result.program
    var = program.vars["x"]
    var.closured?.should be_true
  end

  it "marks variable as closured in program on assign" do
    result = assert_type("x = 1; -> { x = 1 }; x") { int32 }
    program = result.program
    var = program.vars["x"]
    var.closured?.should be_true
  end

  it "marks variable as closured in def" do
    result = assert_type("def foo; x = 1; -> { x }; 1; end; foo") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions.last.as(Call)
    target_def = call.target_def
    var = target_def.vars.not_nil!["x"]
    var.closured?.should be_true
  end

  it "marks variable as closured in block" do
    result = assert_type("
      def foo
        yield
      end

      foo do
        x = 1
        -> { x }
        1
      end
      ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions.last.as(Call)
    block = call.block.not_nil!
    var = block.vars.not_nil!["x"]
    var.closured?.should be_true
  end

  it "unifies types of closured var (1)" do
    assert_type("
      a = 1
      f = -> { a }
      a = 2.5
      a
      ") { union_of(int32, float64) }
  end

  it "unifies types of closured var (2)" do
    assert_type("
      a = 1
      f = -> { a }
      a = 2.5
      f.call
      ") { union_of(int32, float64) }
  end

  it "marks variable as closured inside block in fun" do
    result = assert_type("
      def foo
        yield
      end

      a = 1
      -> { foo { a } }
      a
      ") { int32 }
    program = result.program
    var = program.vars.not_nil!["a"]
    var.closured?.should be_true
  end

  it "doesn't mark var as closured if only used in block" do
    result = assert_type("
      x = 1

      def foo
        yield
      end

      foo { x }
      ") { int32 }
    program = result.program
    var = program.vars["x"]
    var.closured?.should be_false
  end

  it "doesn't mark var as closured if only used in two block" do
    result = assert_type("
      def foo
        yield
      end

      foo do
        x = 1
        foo do
          x
        end
      end
      ", inject_primitives: false) { int32 }
    node = result.node.as(Expressions)
    call = node[1].as(Call)
    block = call.block.not_nil!
    var = block.vars.not_nil!["x"]
    var.closured?.should be_false
  end

  it "doesn't mark self var as closured, but marks method as self closured" do
    result = assert_type("
      class Foo
        def foo
          -> { self }
        end
      end

      Foo.new.foo
      1
    ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions[-2].as(Call)
    target_def = call.target_def
    var = target_def.vars.not_nil!["self"]
    var.closured?.should be_false
    target_def.self_closured?.should be_true
  end

  it "marks method as self closured if instance var is read" do
    result = assert_type("
      class Foo
        @x : Int32?

        def foo
          -> { @x }
        end
      end

      Foo.new.foo
      1
    ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions[-2].as(Call)
    call.target_def.self_closured?.should be_true
  end

  it "marks method as self closured if instance var is written" do
    result = assert_type("
      class Foo
        def foo
          -> { @x = 1 }
        end
      end

      Foo.new.foo
      1
    ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions[-2].as(Call)
    call.target_def.self_closured?.should be_true
  end

  it "marks method as self closured if explicit self call is made" do
    result = assert_type("
      class Foo
        def foo
          -> { self.bar }
        end

        def bar
        end
      end

      Foo.new.foo
      1
    ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions[-2].as(Call)
    call.target_def.self_closured?.should be_true
  end

  it "marks method as self closured if implicit self call is made" do
    result = assert_type("
      class Foo
        def foo
          -> { bar }
        end

        def bar
        end
      end

      Foo.new.foo
      1
    ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions[-2].as(Call)
    call.target_def.self_closured?.should be_true
  end

  it "marks method as self closured if used inside a block" do
    result = assert_type("
      def bar
        yield
      end

      class Foo
        def foo
          ->{ bar { self } }
        end
      end

      Foo.new.foo
      1
    ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions[-2].as(Call)
    call.target_def.self_closured?.should be_true
  end

  it "errors if sending closured proc literal to C" do
    assert_error %(
      lib LibC
        fun foo(callback : ->)
      end

      a = 1
      LibC.foo(-> { a })
      ),
      "can't send closure to C function (closured vars: a)"
  end

  it "errors if sending closured proc pointer to C (1)" do
    assert_error %(
      lib LibC
        fun foo(callback : ->)
      end

      class Foo
        def foo
          LibC.foo(->bar)
        end

        def bar
        end
      end

      Foo.new.foo
      ),
      "can't send closure to C function (closured vars: self)"
  end

  it "errors if sending closured proc pointer to C (2)" do
    assert_error %(
      lib LibC
        fun foo(callback : ->)
      end

      class Foo
        def bar
        end
      end

      foo = Foo.new
      LibC.foo(->foo.bar)
      ),
      "can't send closure to C function (closured vars: self)"
  end

  it "errors if sending closured proc pointer to C (3)" do
    assert_error %(
      lib LibC
        fun foo(callback : ->)
      end

      class Foo
        def initialize
          @a = 1
        end

        def foo
          LibC.foo(->{ @a })
        end
      end

      Foo.new.foo
      ),
      "can't send closure to C function (closured vars: @a)"
  end

  it "transforms block to proc literal" do
    assert_type("
      def foo(&block : Int32 -> Float64)
        block.call(1)
      end

      foo do |x|
        x.to_f
      end
      ") { float64 }
  end

  it "transforms block to proc literal with void type" do
    assert_type("
      def foo(&block : Int32 -> )
        block.call(1)
      end

      foo do |x|
        x.to_f
      end
      ") { nil_type }
  end

  it "errors when transforming block to proc literal if type mismatch" do
    assert_error "
      def foo(&block : Int32 -> Int32)
        block.call(1)
      end

      foo do |x|
        x.to_f
      end
      ",
      "expected block to return Int32, not Float64"
  end

  it "transforms block to proc literal with free var" do
    assert_type("
      def foo(&block : Int32 -> U) forall U
        block.call(1)
      end

      foo do |x|
        x.to_f
      end
      ") { float64 }
  end

  it "transforms block to proc literal without arguments" do
    assert_type("
      def foo(&block : -> U) forall U
        block.call
      end

      foo do
        1.5
      end
      ") { float64 }
  end

  it "errors if giving more block args when transforming block to proc literal" do
    assert_error "
      def foo(&block : -> U)
        block.call
      end

      foo do |x|
        x.to_f
      end
      ",
      "wrong number of block arguments (given 1, expected 0)"
  end

  it "allows giving less block args when transforming block to proc literal" do
    assert_type("
      def foo(&block : Int32 -> U) forall U
        block.call(1)
      end

      foo do
        1.5
      end
      ") { float64 }
  end

  it "allows passing block as proc literal to new and to initialize" do
    assert_type("
      class Foo
        def initialize(&block : Int32 -> Float64)
          @block = block
        end

        def block
          @block
        end
      end

      foo = Foo.new { |x| x.to_f }
      foo.block
      ") { proc_of(int32, float64) }
  end

  it "errors if forwaring block arg doesn't match input type" do
    assert_error "
      def foo(&block : Int32 -> U)
        block
      end

      f = ->(x : Int64) { x + 1 }
      foo &f
      ",
      "expected block argument's argument #1 to be Int32, not Int64"
  end

  it "errors if forwaring block arg doesn't match input type size" do
    assert_error "
      def foo(&block : Int32, Int32 -> U)
        block
      end

      f = ->(x : Int32) { x + 1 }
      foo &f
      ",
      "wrong number of block argument's arguments (given 1, expected 2)"
  end

  it "lookups return type in correct scope" do
    assert_type("
      module Mod
        def foo(&block : Int32 -> T) forall T
          block
        end
      end

      class Foo(T)
        include Mod
      end

      Foo(Int32).new.foo { |x| x.to_f }
      ") { proc_of(int32, float64) }
  end

  it "passes #227" do
    result = assert_type(%(
      ->{ a = 1; ->{ a } }
      ), inject_primitives: false) { proc_of(proc_of(int32)) }
    fn = result.node.as(ProcLiteral)
    fn.def.closure?.should be_false
  end

  it "marks outer fun inside a block as closured" do
    result = assert_type(%(
      def foo
        yield
      end

      a = 1
      ->{ ->{ foo { a } } }
      )) { proc_of(proc_of(int32)) }
    fn = result.node.as(Expressions).last.as(ProcLiteral)
    fn.def.closure?.should be_true
  end

  it "marks outer fun as closured when using self" do
    result = assert_type(%(
      class Foo
        def foo
          ->{ ->{ self } }
        end
      end

      Foo.new.foo
      )) { proc_of(proc_of(types["Foo"])) }
    call = result.node.as(Expressions).last.as(Call)
    a_def = call.target_def
    a_def.self_closured?.should be_true
    fn = (a_def.body.as(ProcLiteral))
    fn.def.closure?.should be_true
  end

  it "can use fun typedef as block type" do
    assert_type(%(
      lib LibC
        alias F = Int32 -> Int32
      end

      def foo(&block : LibC::F)
        block
      end

      foo { |x| x + 1 }
      )) { proc_of(int32, int32) }
  end

  it "says can't send closure to C with new notation" do
    assert_error %(
      lib LibC
        fun foo(x : ->)
      end

      a = 1
      LibC.foo(Proc(Void).new do
        a
      end)
      ),
      "can't send closure to C function (closured vars: a)"
  end
end

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
      ", inject_primitives: true) { union_of(int32, float64) }
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
      ") { int32 }
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

  it "errors if sending closured proc pointer to C (1.2)" do
    assert_error %(
      lib LibC
        fun foo(callback : ->)
      end

      class Foo
        def foo
          LibC.foo(->{ bar })
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
      "can't send closure to C function (closured vars: foo)"
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
      ", inject_primitives: true) { float64 }
  end

  it "transforms block to proc literal with void type" do
    assert_type("
      def foo(&block : Int32 -> )
        block.call(1)
      end

      foo do |x|
        x.to_f
      end
      ", inject_primitives: true) { nil_type }
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
      "expected block to return Int32, not Float64", inject_primitives: true
  end

  it "transforms block to proc literal with free var" do
    assert_type("
      def foo(&block : Int32 -> U) forall U
        block.call(1)
      end

      foo do |x|
        x.to_f
      end
      ", inject_primitives: true) { float64 }
  end

  it "transforms block to proc literal without parameters" do
    assert_type("
      def foo(&block : -> U) forall U
        block.call
      end

      foo do
        1.5
      end
      ", inject_primitives: true) { float64 }
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
      "wrong number of block parameters (given 1, expected 0)"
  end

  it "allows giving less block args when transforming block to proc literal" do
    assert_type("
      def foo(&block : Int32 -> U) forall U
        block.call(1)
      end

      foo do
        1.5
      end
      ", inject_primitives: true) { float64 }
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
      ", inject_primitives: true) { proc_of(int32, float64) }
  end

  it "errors if forwarding block param doesn't match input type" do
    assert_error "
      def foo(&block : Int32 -> U)
        block
      end

      f = ->(x : Int64) { x + 1 }
      foo &f
      ",
      "expected block argument's parameter #1 to be Int32, not Int64", inject_primitives: true
  end

  it "errors if forwarding block param doesn't match input type size" do
    assert_error "
      def foo(&block : Int32, Int32 -> U)
        block
      end

      f = ->(x : Int32) { x + 1 }
      foo &f
      ",
      "wrong number of block argument's parameters (given 1, expected 2)", inject_primitives: true
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
      ", inject_primitives: true) { proc_of(int32, float64) }
  end

  it "passes #227" do
    result = assert_type(%(
      ->{ a = 1; ->{ a } }
      )) { proc_of(proc_of(int32)) }
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
      ), inject_primitives: true) { proc_of(int32, int32) }
  end

  it "says can't send closure to C with new notation" do
    assert_error %(
      struct Proc
        def self.new(&block : self)
          block
        end
      end

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

  it "says can't send closure to C with captured block" do
    assert_error %(
      def capture(&block : -> Int32)
        block
      end

      lib LibC
        fun foo(x : ->)
      end

      a = 1
      LibC.foo(capture do
        a
      end)
      ),
      "can't send closure to C function (closured vars: a)"
  end

  it "doesn't crash for non-existing variable (#3789)" do
    assert_error %(
      lib LibFoo
        fun foo(->)
      end

      x = 0
      LibFoo.foo(->{
        x = ->(data : Int32) {
          data
        }
      })
      ),
      "can't send closure to C function (closured vars: x)"
  end

  it "doesn't closure typeof local var" do
    result = assert_type("x = 1; -> { typeof(x) }; x") { int32 }
    program = result.program
    var = program.vars["x"]
    var.closured?.should be_false
  end

  it "doesn't closure typeof instance var (#9479)" do
    result = assert_type("
      class Foo
        @x : Int32?

        def foo
          -> { typeof(@x) }
        end
      end

      Foo.new.foo
      1
    ") { int32 }
    node = result.node.as(Expressions)
    call = node.expressions[-2].as(Call)
    call.target_def.self_closured?.should be_false
  end

  it "correctly detects previous var as closured (#5609)" do
    assert_error %(
      def block(&block)
        block.call
      end
      def times
        yield
        yield
      end
      x = 1
      times do
        if x.is_a?(Int32)
          x &+ 2
        end
        block do
          x = "hello"
        end
      end
      ),
      "undefined method '&+' for String", inject_primitives: true
  end

  it "doesn't assign all types to metavar if closured but only assigned to once" do
    assert_no_errors <<-CRYSTAL, inject_primitives: true
      def capture(&block)
        block
      end
      x = 1 == 2 ? 1 : nil
      if x
        capture do
          x &+ 1
        end
      end
      CRYSTAL
  end

  it "does assign all types to metavar if closured but only assigned to once in a loop" do
    assert_error %(
      def capture(&block)
        block
      end
      while 1 == 1
        x = 1 == 2 ? 1 : nil
        if x
          capture do
            x &+ 1
          end
        end
      end
      ),
      "undefined method '&+'", inject_primitives: true
  end

  it "does assign all types to metavar if closured but only assigned to once in a loop through block" do
    assert_error %(
      def capture(&block)
        block
      end

      def loop
        while 1 == 1
          yield
        end
      end

      x = 1
      loop do
        x = 1 == 2 ? 1 : nil
        if x
          capture do
            x &+ 1
          end
        end
      end
      ),
      "undefined method '&+'", inject_primitives: true
  end

  it "does assign all types to metavar if closured but only assigned to once in a loop through captured block" do
    assert_error %(
      def capture(&block)
        block
      end

      def loop(&block)
        while 1 == 1
          block.call
        end
      end

      x = 1
      loop do
        x = 1 == 2 ? 1 : nil
        if x
          capture do
            x &+ 1
          end
        end
      end
      ),
      "undefined method '&+'", inject_primitives: true
  end

  it "doesn't assign all types to metavar if closured but declared inside block and never re-assigned" do
    assert_no_errors %(
      def capture(&block)
        block
      end

      def loop(&block)
        yield
      end

      loop do
        x = 1 == 2 ? 1 : nil
        if x
          capture do
            x &+ 1
          end
        end
      end
      ), inject_primitives: true
  end

  it "doesn't assign all types to metavar if closured but declared inside block and re-assigned inside the same context before the closure" do
    assert_no_errors %(
      def capture(&block)
        block
      end

      def loop(&block)
        yield
      end

      loop do
        x = 1 == 2 ? 1 : nil
        x = 1 == 2 ? 1 : nil
        if x
          capture do
            x &+ 1
          end
        end
      end
      ), inject_primitives: true
  end

  it "is considered as closure if assigned once but comes from a method arg" do
    assert_error %(
      def capture(&block)
        block
      end
      def foo(x)
        capture do
          x &+ 1
        end
        x = 1 == 2 ? 1 : nil
      end
      foo(1)
      ),
      "undefined method '&+'"
  end

  it "considers var as closure-readonly if it was assigned multiple times before it was closured" do
    assert_no_errors(%(
      def capture(&block)
        block
      end

      x = "hello"
      x = 1

      capture do
        x &+ 1
      end
      ), inject_primitives: true)
  end

  it "correctly captures type of closured block arg" do
    assert_type(%(
      def capture(&block)
        block.call
      end
      def foo
        yield nil
      end
      z = nil
      foo do |x|
        capture do
          x = 1
        end
        z = x
      end
      z
      ), inject_primitives: true) { nilable int32 }
  end
end

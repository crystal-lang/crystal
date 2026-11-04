require "../../spec_helper"

private def wasm_shadow_ir(source, debug = Crystal::Debug::Default)
  program = Crystal::Program.new
  program.codegen_target = Crystal::Codegen::Target.new("wasm32-wasip1")
  program.target_machine = program.codegen_target.to_target_machine
  program.flags.concat(%w(without_mt without_zlib))
  program.flags << "debug" unless debug.none?
  program.define_crystal_constants
  node = program.normalize(parse(source, filename: "wasm_proc.cr"))
  node = program.semantic(node)
  mod = program.codegen(node, single_module: true, debug: debug)[""].mod
  mod.verify
  mod.to_s
end

private def find_function_body(ir, name)
  ir.split("\ndefine ")
    .find! { |function| function.lines.first.includes?(name) }
    .split("\n}")
    .first
end

describe "Code gen: WASM shadow stack" do
  it "pushes and pops source frames without emitting DWARF by default" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      def foo
        42
      end
      foo
      CRYSTAL
    ir.should contain("@__crystal_shadow_stack_head = global ptr null")
    ir.should contain("shadow_stack_frame = alloca")
    ir.should contain("shadow_stack_metadata")
    ir.should contain("store ptr")

    ir.lines.each_cons(3).any? do |lines|
      lines[0].includes?(" = load ptr") &&
        lines[1].includes?("store ptr") && lines[1].includes?("@__crystal_shadow_stack_head") &&
        lines[2].strip.starts_with?("ret ")
    end.should be_true

    # doesn't emit dwarf
    ir.should_not contain("!DICompileUnit")
    ir.should_not contain("!DISubprogram")
    ir.should_not contain("Debug Info Version")
  end

  it "disables frames with no debug information" do
    ir = wasm_shadow_ir("1", Crystal::Debug::None)
    ir.should_not contain("shadow_stack")
    ir.should_not contain("!DICompileUnit")
  end

  it "disables shadow-stack access in raising methods with no debug information" do
    ir = wasm_shadow_ir(<<-CRYSTAL, Crystal::Debug::None)
      @[Primitive(:shadow_stack_head)]
      def stack_head : Void*
      end

      @[Raises]
      def raise
        stack_head
      end

      raise
      CRYSTAL
    ir.should_not contain("shadow_stack")
    ir.should contain("ret ptr null")
  end

  it "emits both DWARF and frames in full debug mode" do
    ir = wasm_shadow_ir("1", Crystal::Debug::Full)
    ir.should contain("shadow_stack_frame")
    ir.should contain("!DICompileUnit")
  end

  it "omits frames and call locations for non-raising methods and primitives" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      require "primitives"

      @[NoInline]
      def pure_method(value : Int32)
        value &+ 1
      end

      pure_method(42)
      CRYSTAL

    find_function_body(ir, "pure_method").should_not contain("shadow_stack")

    # only the initial location of the top-level frame remains
    ir.lines.count { |line| line.starts_with?("@shadow_stack_metadata") }.should eq(1)
  end

  it "does not update locations for LLVM intrinsics" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      lib Intrinsics
        fun sqrt = "llvm.sqrt.f64"(value : Float64) : Float64
      end
      Intrinsics.sqrt(4.0)
      CRYSTAL
    ir.should contain("@llvm.sqrt.f64")
    ir.lines.count { |line| line.starts_with?("@shadow_stack_metadata") }.should eq(1)
  end

  it "keeps overflow locations for checked arithmetic primitives" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      require "primitives"

      @[Raises]
      def raise : NoReturn
        x = uninitialized NoReturn
        x
      end

      fun __crystal_raise_overflow : NoReturn
        raise
      end

      def checked_method(value : Int32)
        value + 1
      end

      checked_method(42)
      CRYSTAL

    body = find_function_body(ir, "checked_method")
    body.should contain("shadow_stack_frame = alloca")
    body.should contain("@__crystal_raise_overflow")
  end

  it "keeps frames and call locations for explicitly raising methods" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      @[Raises]
      @[NoInline]
      def capture
        asm("nop" :::: "volatile")
        42
      end

      def wrapper
        capture
      end

      wrapper
      CRYSTAL

    find_function_body(ir, "capture").should contain("shadow_stack_frame = alloca")
    find_function_body(ir, "wrapper").should contain("shadow_stack_frame = alloca")
  end

  it "omits frames for non-raising procs" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      require "primitives"
      -> { 42 }.call
      CRYSTAL
    find_function_body(ir, "wasm_proc").should_not contain("shadow_stack")
  end

  it "omits frames for non-raising closures" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      require "primitives"

      def capture(&block : -> Int32)
        block
      end

      value = 42
      capture { value }.call
      CRYSTAL

    find_function_body(ir, "wasm_proc").should_not contain("shadow_stack")
  end

  it "keeps frames for raising procs" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      require "primitives"

      lib LibTest
        @[Raises]
        fun raising : NoReturn
      end

      -> { LibTest.raising }.call
      CRYSTAL

    find_function_body(ir, "wasm_proc").should contain("shadow_stack_frame = alloca")
  end

  it "keeps frames for closures calling raising methods without framing their factory" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      require "primitives"

      lib LibTest
        @[Raises]
        fun capture : Int32
      end

      def make_capture(value : Int32)
        -> { value; LibTest.capture }
      end

      make_capture(42).call
      CRYSTAL

    find_function_body(ir, "wasm_proc").should contain("shadow_stack_frame = alloca")
    find_function_body(ir, "make_capture").should_not contain("shadow_stack")
  end

  it "restores the current frame when entering a WASM handler" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      class Exception
      end

      @[Raises]
      def raise(message) : NoReturn
        x = uninitialized NoReturn
        x
      end

      fun __crystal_raise(exception : Void*) : NoReturn
        raise exception
      end

      begin
        raise "test"
      rescue
        1
      ensure
        2
      end
      CRYSTAL

    ir.should contain("catchpad")

    ir.lines.each_cons(2).any? do |pair|
      pair[0].starts_with?("catch_target:") &&
        pair[1].includes?("store ptr %shadow_stack_frame, ptr @__crystal_shadow_stack_head")
    end.should be_true
  end

  it "excludes naked function bodies" do
    ir = wasm_shadow_ir(<<-CRYSTAL)
      @[Naked]
      def raw : Nil
        asm("nop" :::: "volatile")
      end
      raw
      CRYSTAL
    body = find_function_body(ir, "raw")
    body.should contain("ret void")
    body.should_not contain("shadow_stack")
  end
end

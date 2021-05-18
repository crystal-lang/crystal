require "./repl"
require "ffi"

class Crystal::Repl::Interpreter
  Trace  = false
  TimeIt = false

  record CallFrame,
    compiled_def : CompiledDef,
    instructions : Array(UInt8),
    ip : Pointer(UInt8),
    stack : Pointer(UInt8),
    stack_bottom : Pointer(UInt8),
    block_caller_frame_index : Int32

  def initialize(program : Program)
    @program = program
    @local_vars = LocalVars.new(program)

    @defs = {} of Def => CompiledDef
    @defs.compare_by_identity

    @dl_libraries = {} of String? => Void*
    @instructions = [] of Instruction

    # TODO: what if the stack is exhausted?
    @stack = uninitialized UInt8[8096]

    @call_stack = [] of CallFrame

    @main_visitor = MainVisitor.new(@program)
    @top_level_visitor = TopLevelVisitor.new(@program)
    @cleanup_transformer = CleanupTransformer.new(@program)
  end

  def interpret(node : ASTNode) : Value
    node = @program.normalize(node)

    @top_level_visitor.reset
    node.accept @top_level_visitor

    @main_visitor.reset
    node.accept @main_visitor

    node = node.transform(@cleanup_transformer)

    # Declare local variables
    # TODO: reuse previously declared variables
    @main_visitor.meta_vars.each do |name, meta_var|
      @local_vars.declare(name, meta_var.type)
    end

    compiler = Compiler.new(@program, @defs, @local_vars)
    @instructions = compiler.compile(node)

    {% if Compiler::Decompile %}
      puts "=== top-level ==="
      p @local_vars
      puts Disassembler.disassemble(@instructions, @local_vars)
      puts "=== top-level ==="
    {% end %}

    time = Time.monotonic
    value = interpret(node.type)
    {% if TimeIt %}
      puts "Elapsed: #{Time.monotonic - time}"
    {% end %}

    value
  end

  def local_var_keys
    @local_vars.names
  end

  def interpret(node_type : Type) : Value
    stack_bottom = @stack.to_unsafe

    # Shift stack to leave ream for local vars
    # Previous runs that wrote to local vars would have those values
    # written to @stack alreay
    stack_bottom_after_local_vars = stack_bottom + @local_vars.bytesize
    stack = stack_bottom_after_local_vars

    instructions = @instructions
    ip = instructions.to_unsafe
    return_value = Pointer(UInt8).null

    @call_stack << CallFrame.new(
      compiled_def: CompiledDef.new(
        program: @program,
        def: Def.new("main").tap { |a_def| a_def.owner = @program },
        args_bytesize: 0,
        instructions: instructions,
        local_vars: @local_vars,
      ),
      instructions: instructions,
      ip: ip,
      stack: stack,
      stack_bottom: stack_bottom,
      block_caller_frame_index: -1,
    )

    while true
      {% if Trace %}
        puts

        call_frame = @call_stack.last
        a_def = call_frame.compiled_def.def
        puts "In: #{a_def.owner}##{a_def.name}"
        puts "Call stack size: #{@call_stack.size}"

        Disassembler.disassemble_one(instructions, (ip - instructions.to_unsafe).to_i32, current_local_vars, STDOUT)
        puts
      {% end %}

      op_code = next_instruction OpCode

      {% begin %}
        case op_code
          {% for name, instruction in Crystal::Repl::Instructions %}
            {% operands = instruction[:operands] %}
            {% pop_values = instruction[:pop_values] %}

            in .{{name.id}}?
              {% for operand in operands %}
                {{operand.var}} = next_instruction {{operand.type}}
              {% end %}

              {% for pop_value, i in pop_values %}
                {% pop = pop_values[pop_values.size - i - 1] %}
                {{ pop.var }} = stack_pop({{pop.type}})
              {% end %}

              {% if instruction[:push] %}
                stack_push({{instruction[:code]}})
              {% else %}
                {{instruction[:code]}}
              {% end %}
          {% end %}
        end
      {% end %}

      {% if Trace %}
        puts Slice.new(@stack.to_unsafe, stack - @stack.to_unsafe).hexdump
        # stack_size = stack - @stack.to_unsafe
        # print "Stack: "
        # stack_size.times do |i|
        #   print stack_bottom[i].to_s(16).rjust(2, '0')
        #   print " " unless i == stack_size - 1
        # end
        # puts

        # print "       "
        # @local_vars.each_name_index_and_size do |name, index, size|
        #   next if size == 0

        #   print "-" * (2 + (3 * (size - 1)))
        #   print " "
        # end
        # puts

        # print "       "
        # @local_vars.each_name_index_and_size do |name, index, size|
        #   next if size == 0

        #   width = (2 + (3 * (size - 1)))
        #   part = name[0...width]
        #   print part
        #   print " " * (width - part.size)

        #   print " "
        # end
        # puts
      {% end %}
    end

    if stack != stack_bottom_after_local_vars
      raise "BUG: data left on stack (#{stack - stack_bottom_after_local_vars} bytes): #{Slice.new(@stack.to_unsafe, stack - @stack.to_unsafe)}"
    end

    Value.new(@program, return_value, node_type)
  end

  private def current_local_vars
    if call_frame = @call_stack.last?
      call_frame.compiled_def.local_vars
    else
      @local_vars
    end
  end

  private macro call(compiled_def, block_caller_frame_index = -1)
    # At the point of a call like:
    #
    #     foo(x, y)
    #
    # x and y will already be in the stack, ready to be used
    # as the function arguments in the target def.
    #
    # After the call, we want the stack to be at the point
    # where it doesn't have the call args, ready to push
    # return call's return value.
    %stack_before_call_args = stack - {{compiled_def}}.args_bytesize
    @call_stack[-1] = @call_stack.last.copy_with(
      ip: ip,
      stack: %stack_before_call_args,
    )

    %call_frame = CallFrame.new(
      compiled_def: {{compiled_def}},
      instructions: {{compiled_def}}.instructions,
      ip: {{compiled_def}}.instructions.to_unsafe,
      # We need to adjust the call stack to start right
      # after the target def's local variables.
      stack: %stack_before_call_args + {{compiled_def}}.local_vars.bytesize,
      stack_bottom: %stack_before_call_args,
      block_caller_frame_index: {{block_caller_frame_index}},
    )

    @call_stack << %call_frame

    instructions = %call_frame.compiled_def.instructions
    ip = %call_frame.ip
    stack = %call_frame.stack
    stack_bottom = %call_frame.stack_bottom
  end

  private macro call_with_block(compiled_def)
    call({{compiled_def}}, block_caller_frame_index: @call_stack.size - 1)
  end

  private macro call_block(compiled_block)
    # At this point the stack has the yield expressions, so after the call
    # we must go back to before the yield expressions
    %stack_before_call_args = stack - {{compiled_block}}.args_bytesize
    @call_stack[-1] = @call_stack.last.copy_with(
      ip: ip,
      stack: %stack_before_call_args,
    )

    copied_call_frame = @call_stack[@call_stack.last.block_caller_frame_index].copy_with(
      instructions: {{compiled_block}}.instructions,
      ip: {{compiled_block}}.instructions.to_unsafe,
      stack: stack,
    )
    @call_stack << copied_call_frame

    instructions = copied_call_frame.instructions
    ip = copied_call_frame.ip
    stack_bottom = copied_call_frame.stack_bottom
  end

  private macro leave(size)
    if @call_stack.size == 1
      @call_stack.pop
      return_value = Pointer(UInt8).malloc({{size}})
      return_value.copy_from(stack_bottom_after_local_vars, {{size}})
      stack -= {{size}}
      break
    else
      # Remember the point the stack reached
      old_stack = stack
      @call_stack.pop
      %call_frame = @call_stack.last

      # Restore ip, instructions and stack bottom
      instructions = %call_frame.compiled_def.instructions
      ip = %call_frame.ip
      stack_bottom = %call_frame.stack_bottom
      stack = %call_frame.stack

      # Ccopy the return value
      stack_move_from(old_stack - {{size}}, {{size}})

      # TODO: clean up stack
    end
  end

  private macro set_ip(ip)
    ip = instructions.to_unsafe + {{ip}}
  end

  private macro set_local_var(index, size)
    stack_move_to(stack_bottom + {{index}}, {{size}})
  end

  private macro get_local_var(index, size)
    stack_move_from(stack_bottom + {{index}}, {{size}})
  end

  private macro get_local_var_pointer(index)
    stack_bottom + {{index}}
  end

  private macro next_instruction(t)
    value = ip.as({{t}}*).value
    ip += sizeof({{t}})
    value
  end

  private macro self_class_pointer
    get_local_var_pointer(0).as(Pointer(Pointer(UInt8))).value
  end

  private macro stack_pop(t)
    value = (stack - sizeof({{t}})).as({{t}}*).value
    stack_shrink_by(sizeof({{t}}))
    value
  end

  private macro stack_push(value)
    %temp = {{value}}
    stack.as(Pointer(typeof({{value}}))).value = %temp
    stack_grow_by(sizeof(typeof({{value}})))
  end

  private macro stack_copy_to(pointer, size)
    (stack - {{size}}).copy_to({{pointer}}, {{size}})
  end

  private macro stack_move_to(pointer, size)
    stack_copy_to({{pointer}}, {{size}})
    stack_shrink_by({{size}})
  end

  private macro stack_move_from(pointer, size)
    stack.copy_from({{pointer}}, {{size}})
    stack_grow_by({{size}})
  end

  private macro stack_grow_by(size)
    stack += {{size}}
  end

  private macro stack_shrink_by(size)
    stack -= {{size}}
  end

  private def sizeof_type(type : Type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end

  private def type_from_type_id(id : Int32) : Type
    @program.llvm_id.type_from_id(id)
  end

  private macro type_id_bytesize
    8
  end

  def define_primitives
    exception = @program.types["Exception"]?
    if exception
      call_stack = exception.types["CallStack"]?
      if call_stack
        unwind_signature = CallSignature.new(
          name: "unwind",
          arg_types: [] of Type,
          block: nil,
          named_args: nil,
        )

        matches = call_stack.metaclass.lookup_matches(unwind_signature)
        unless matches.empty?
          unwind_def = matches.matches.not_nil!.first.def
          unwind_def.body = Primitive.new("repl_call_stack_unwind")
        end
      end

      raise_without_backtrace_signature = CallSignature.new(
        name: "raise_without_backtrace",
        arg_types: [exception] of Type,
        block: nil,
        named_args: nil,
      )

      matches = @program.lookup_matches(raise_without_backtrace_signature)
      if matches.empty?
        puts "OH NO!"
      else
        raise_without_backtrace_def = matches.matches.not_nil!.first.def
        raise_without_backtrace_def.body = Primitive.new("repl_raise_without_backtrace")
      end
    end
  end

  private def define_primitive_raise_without_backtrace
  end
end

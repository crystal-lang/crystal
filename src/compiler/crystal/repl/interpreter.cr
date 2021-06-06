require "./repl"
require "ffi"
require "colorize"

class Crystal::Repl::Interpreter
  record CallFrame,
    # The CompiledDef related to this call frame
    compiled_def : CompiledDef,
    # Instructions for this frame
    instructions : Array(UInt8),
    # Nodes to related instructions indexes back to ASTNodes (mainly for location purposes)
    nodes : Hash(Int32, ASTNode),
    # The pointer to the current instruction for this call frame.
    # This value changes as the program goes, and when a call is made
    # this value is useful to know where we need to continue after
    # the call returns.
    ip : Pointer(UInt8),
    # What's the frame's stack.
    # This value changes as the program goes, and when a call is made
    # this value is useful to know what values in the stack we need
    # to have when the call returns.
    stack : Pointer(UInt8),
    # What's the frame's stack bottom. After this position come the
    # def's local variables.
    stack_bottom : Pointer(UInt8),
    # The index of the frame that called a block.
    # This is useful to know because when a `yield` happens,
    # we more or less create a new stack frame that has the same
    # local variables as this frame, because the block will need
    # to access that frame's variables.
    # It's -1 if the value is not present.
    block_caller_frame_index : Int32,
    # When a `yield` happens we copy the frame pointed by
    # `block_caller_frame_index`. If a `return` happens inside
    # that block we need to return from that frame (the `def`s one.)
    # With `real_frame_index` we know where that frame is actually
    # in the call stack (the original, not the copy) and we can
    # go back to just before that frame when a `return` happens.
    real_frame_index : Int32,
    # When we jump to do a constant initialization we store the
    # index where to store the constant value in the `@constants`
    # memory location.
    # It's -1 if no constant needs to be initialized.
    constant_index : Int32

  @pry_node : ASTNode?
  @pry_max_target_frame : Int32?

  getter local_vars : LocalVars

  def initialize(@context : Context)
    @local_vars = LocalVars.new(@context)

    @instructions = [] of Instruction
    @nodes = {} of Int32 => ASTNode

    # TODO: what if the stack is exhausted?
    @stack = Pointer(UInt8).malloc(8 * 1024 * 1024)
    @call_stack = [] of CallFrame
    @constants = Pointer(UInt8).null
    @class_vars = Pointer(UInt8).null

    @main_visitor = MainVisitor.new(program)
    @top_level_visitor = TopLevelVisitor.new(program)
    @cleanup_transformer = CleanupTransformer.new(program)
    @block_level = 0

    @compiled_def = nil
    @pry = false
    @pry_node = nil
    @pry_max_target_frame = nil
  end

  def initialize(interpreter : Interpreter, compiled_def : CompiledDef, location : Location, stack : Pointer(UInt8))
    @context = interpreter.@context
    @local_vars = compiled_def.local_vars.dup

    @instructions = [] of Instruction
    @nodes = {} of Int32 => ASTNode

    @stack = stack
    # TODO: copy the call stack from the main interpreter
    @call_stack = [] of CallFrame
    @constants = interpreter.@constants
    @class_vars = interpreter.@class_vars

    gatherer = LocalVarsGatherer.new(location, compiled_def.def)
    gatherer.gather
    meta_vars = gatherer.meta_vars
    @block_level = gatherer.block_level

    @main_visitor = MainVisitor.new(
      interpreter.@context.program,
      vars: meta_vars,
      meta_vars: meta_vars,
      typed_def: compiled_def.def)
    @main_visitor.scope = compiled_def.def.owner
    @main_visitor.path_lookup = compiled_def.def.owner # TODO: this is probably not right

    @top_level_visitor = interpreter.@top_level_visitor
    @cleanup_transformer = interpreter.@cleanup_transformer

    @compiled_def = compiled_def
    @pry = false
    @pry_node = nil
    @pry_max_target_frame = nil
  end

  def interpret(node : ASTNode) : Value
    node = program.normalize(node)

    @top_level_visitor.backup do
      node.accept @top_level_visitor
    end

    @main_visitor.backup do
      node.accept @main_visitor
    end

    node = node.transform(@cleanup_transformer)

    compiled_def = @compiled_def

    # Declare local variables
    # TODO: reuse previously declared variables

    # Don't declare local variables again if we are in the middle of pry
    unless compiled_def
      @main_visitor.meta_vars.each do |name, meta_var|
        existing_type = @local_vars.type?(name, 0)
        if existing_type
          if existing_type != meta_var.type
            raise "BUG: can't change type of local variable #{name} from #{existing_type} to #{meta_var.type} yet"
          end
        else
          @local_vars.declare(name, meta_var.type)
        end
      end
    end

    compiler =
      if compiled_def
        Compiler.new(@context, @local_vars, scope: compiled_def.def.owner, def: compiled_def.def)
      else
        Compiler.new(@context, @local_vars)
      end
    compiler.block_level = @block_level
    compiler.compile(node)

    @instructions = compiler.instructions
    @nodes = compiler.nodes

    if @context.decompile
      if compiled_def
        puts "=== #{compiled_def.def.owner}##{compiled_def.def.name} ==="
      else
        puts "=== top-level ==="
      end
      puts @local_vars
      puts Disassembler.disassemble(@instructions, @nodes, @local_vars)

      if compiled_def
        puts "=== #{compiled_def.def.owner}##{compiled_def.def.name} ==="
      else
        puts "=== top-level ==="
      end
    end

    time = Time.monotonic
    value = interpret(node, node.type)
    if @context.stats
      puts "Elapsed: #{Time.monotonic - time}"
    end

    value
  end

  def interpret(node : ASTNode, node_type : Type) : Value
    stack_bottom = @stack

    # Shift stack to leave ream for local vars
    # Previous runs that wrote to local vars would have those values
    # written to @stack alreay
    stack_bottom_after_local_vars = stack_bottom + @local_vars.max_bytesize
    stack = stack_bottom_after_local_vars

    # Reserve space for constants
    @constants = @constants.realloc(@context.constants.bytesize)

    # Reserve space for class vars
    @class_vars = @class_vars.realloc(@context.class_vars.bytesize)

    instructions = @instructions
    nodes = @nodes
    ip = instructions.to_unsafe
    return_value = Pointer(UInt8).null

    compiled_def = @compiled_def
    if compiled_def
      a_def = compiled_def.def
    else
      a_def = Def.new("<top-level>", body: node)
      a_def.owner = program
      a_def.vars = program.vars
    end

    @call_stack << CallFrame.new(
      compiled_def: CompiledDef.new(
        context: @context,
        def: a_def,
        args_bytesize: 0,
        instructions: instructions,
        nodes: @nodes,
        local_vars: @local_vars,
      ),
      instructions: instructions,
      nodes: nodes,
      ip: ip,
      stack: stack,
      stack_bottom: stack_bottom,
      block_caller_frame_index: -1,
      real_frame_index: 0,
      constant_index: -1,
    )

    while true
      if @context.trace
        puts

        call_frame = @call_stack.last
        a_def = call_frame.compiled_def.def
        offset = (ip - instructions.to_unsafe).to_i32
        puts "In: #{a_def.owner}##{a_def.name}"
        node = nodes[offset]?
        puts "Node: #{node}" if node
        puts Slice.new(@stack, stack - @stack).hexdump

        Disassembler.disassemble_one(instructions, offset, nodes, current_local_vars, STDOUT)
        puts
      end

      if @pry
        pry_max_target_frame = @pry_max_target_frame
        if !pry_max_target_frame || @call_stack.size <= pry_max_target_frame
          pry(ip, instructions, nodes, stack_bottom, stack)
        end
      end

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

      if @context.trace
        puts Slice.new(@stack, stack - @stack).hexdump
      end
    end

    if stack != stack_bottom_after_local_vars
      raise "BUG: data left on stack (#{stack - stack_bottom_after_local_vars} bytes): #{Slice.new(@stack, stack - @stack)}"
    end

    Value.new(@context, return_value, node_type)
  end

  private def current_local_vars
    if call_frame = @call_stack.last?
      call_frame.compiled_def.local_vars
    else
      @local_vars
    end
  end

  private macro call(compiled_def,
                     block_caller_frame_index = -1,
                     constant_index = -1)
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

    # Clear the portion after the call args and upto the def local vars
    # because it might contain garbage data from previous block calls or
    # method calls.
    %size_to_clear = {{compiled_def}}.local_vars.max_bytesize - {{compiled_def}}.args_bytesize
    if %size_to_clear < 0
      raise "OH NO, size to clear DEF is: #{ %size_to_clear }"
    end

    stack.clear(%size_to_clear)

    @call_stack[-1] = @call_stack.last.copy_with(
      ip: ip,
      stack: %stack_before_call_args,
    )

    %call_frame = CallFrame.new(
      compiled_def: {{compiled_def}},
      instructions: {{compiled_def}}.instructions,
      nodes: {{compiled_def}}.nodes,
      ip: {{compiled_def}}.instructions.to_unsafe,
      # We need to adjust the call stack to start right
      # after the target def's local variables.
      stack: %stack_before_call_args + {{compiled_def}}.local_vars.max_bytesize,
      stack_bottom: %stack_before_call_args,
      block_caller_frame_index: {{block_caller_frame_index}},
      real_frame_index: @call_stack.size,
      constant_index: {{constant_index}},
    )

    @call_stack << %call_frame

    instructions = %call_frame.compiled_def.instructions
    nodes = %call_frame.compiled_def.nodes
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

    %block_caller_frame_index = @call_stack.last.block_caller_frame_index

    copied_call_frame = @call_stack[%block_caller_frame_index].copy_with(
      instructions: {{compiled_block}}.instructions,
      nodes: {{compiled_block}}.nodes,
      ip: {{compiled_block}}.instructions.to_unsafe,
      stack: stack,
    )
    @call_stack << copied_call_frame

    instructions = copied_call_frame.instructions
    nodes = copied_call_frame.nodes
    ip = copied_call_frame.ip
    stack_bottom = copied_call_frame.stack_bottom

    %offset_to_clear = {{compiled_block}}.locals_bytesize_start + {{compiled_block}}.args_bytesize
    %size_to_clear = {{compiled_block}}.locals_bytesize_end - {{compiled_block}}.locals_bytesize_start - {{compiled_block}}.args_bytesize
    if %size_to_clear < 0
      raise "OH NO, size to clear BLOCK is: #{ %size_to_clear }"
    end

    # Clear the portion after the block args and upto the block local vars
    # because it might contain garbage data from previous block calls or
    # method calls.
    #
    # stack ... locals ... locals_bytesize_start ... args_bytesize ... locals_bytesize_end
    #                                                            [ ..................... ]
    #                                                                   delete this
    (stack_bottom + %offset_to_clear).clear(%size_to_clear)
  end

  private macro lib_call(lib_function)
    %target_def = lib_function.def
    %cif = lib_function.call_interface
    %fn = lib_function.symbol

    # Assume C calls don't have more than 100 arguments
    # TODO: for speed, maybe compute these offsets and sizes back in the Compiler
    %pointers = uninitialized StaticArray(Pointer(Void), 100)
    %offset = 0
    %i = %target_def.args.size - 1
    %target_def.args.reverse_each do |arg|
      %arg_bytesize = aligned_sizeof_type(arg.type)
      %pointers[%i] = (stack - %offset - %arg_bytesize).as(Void*)
      %offset -= %arg_bytesize
      %i -= 1
    end
    %cif.call(%fn, %pointers.to_unsafe, stack.as(Void*))

    %return_bytesize = inner_sizeof_type(%target_def.type)
    %aligned_return_bytesize = align(%return_bytesize)

    (stack + %offset).move_from(stack, %return_bytesize)
    stack = stack + %offset + %return_bytesize
    stack_clear(%aligned_return_bytesize - %return_bytesize)
  end

  private macro leave(size)
    # Remember the point the stack reached
    %old_stack = stack
    %previous_call_frame = @call_stack.pop

    leave_after_pop_call_frame(%old_stack, %previous_call_frame, {{size}})
  end

  private macro leave_def(size)
    # Remember the point the stack reached
    %old_stack = stack
    %previous_call_frame = @call_stack.pop

    until @call_stack.size == %previous_call_frame.real_frame_index
      @call_stack.pop
    end

    leave_after_pop_call_frame(%old_stack, %previous_call_frame, {{size}})
  end

  private macro break_block(size)
    # Remember the point the stack reached
    %old_stack = stack
    %previous_call_frame = @call_stack.pop

    until @call_stack.size - 1 == %previous_call_frame.real_frame_index
      @call_stack.pop
    end

    leave_after_pop_call_frame(%old_stack, %previous_call_frame, {{size}})
  end

  private macro leave_after_pop_call_frame(old_stack, previous_call_frame, size)
    if @call_stack.empty?
      return_value = Pointer(UInt8).malloc({{size}})
      return_value.copy_from(stack_bottom_after_local_vars, {{size}})
      stack_shrink_by({{size}})
      break
    else
      %old_stack = {{old_stack}}
      %previous_call_frame = {{previous_call_frame}}
      %call_frame = @call_stack.last

      # Restore ip, instructions and stack bottom
      instructions = %call_frame.instructions
      nodes = %call_frame.nodes
      ip = %call_frame.ip
      stack_bottom = %call_frame.stack_bottom
      stack = %call_frame.stack

      # Copy the return value to a constant, if the frame was for a constant
      if %previous_call_frame.constant_index != -1
        (%old_stack - {{size}}).copy_to(@constants + %previous_call_frame.constant_index + Constants::OFFSET_FROM_INITIALIZED, {{size}})
      end

      # Ccopy the return value
      stack_move_from(%old_stack - {{size}}, {{size}})

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

  private macro get_ivar_pointer(offset)
    self_class_pointer + offset
  end

  private macro get_const(index, size)
    # TODO: make this atomic
    %initialized = @constants[{{index}}]
    if %initialized == 1_u8
      stack_move_from(@constants + {{index}} + Constants::OFFSET_FROM_INITIALIZED, {{size}})
    else
      @constants[{{index}}] = 1_u8
      %compiled_def = @context.constants.index_to_compiled_def({{index}})
      call(%compiled_def, constant_index: {{index}})
    end
  end

  private macro get_class_var(index, size)
    # TODO: initialized
    stack_move_from(@class_vars + {{index}} + ClassVars::OFFSET_FROM_INITIALIZED, {{size}})
  end

  private macro set_class_var(index, size)
    stack_move_to(@class_vars + {{index}} + ClassVars::OFFSET_FROM_INITIALIZED, {{size}})
  end

  private macro pry
    @pry = true
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
    %aligned_size = align(sizeof({{t}}))
    %value = (stack - %aligned_size).as({{t}}*).value
    stack_shrink_by(%aligned_size)
    %value
  end

  private macro stack_push(value)
    %temp = {{value}}
    stack.as(Pointer(typeof({{value}}))).value = %temp

    %size = sizeof(typeof({{value}}))
    %aligned_size = align(%size)
    stack += %size
    stack_grow_by(%aligned_size - %size)
  end

  private macro stack_copy_to(pointer, size)
    (stack - {{size}}).copy_to({{pointer}}, {{size}})
  end

  private macro stack_move_to(pointer, size)
    %size = {{size}}
    %aligned_size = align(%size)
    (stack - %aligned_size).copy_to({{pointer}}, %size)
    stack_shrink_by(%aligned_size)
  end

  private macro stack_move_from(pointer, size)
    %size = {{size}}
    %aligned_size = align(%size)

    stack.copy_from({{pointer}}, %size)
    stack += %size
    stack_grow_by(%aligned_size - %size)
  end

  private macro stack_grow_by(size)
    stack_clear({{size}})
    stack += {{size}}
  end

  private macro stack_shrink_by(size)
    stack -= {{size}}
    stack_clear({{size}})
  end

  private macro stack_clear(size)
    # TODO: clearing the stack after every step is very slow!
    stack.clear({{size}})
  end

  private def aligned_sizeof_type(type : Type) : Int32
    @context.aligned_sizeof_type(type)
  end

  private def inner_sizeof_type(type : Type) : Int32
    @context.inner_sizeof_type(type)
  end

  private def type_from_type_id(id : Int32) : Type
    program.llvm_id.type_from_id(id)
  end

  private macro type_id_bytesize
    8
  end

  private def align(value : Int32)
    @context.align(value)
  end

  def define_primitives
    exception = program.types["Exception"]?
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

      matches = program.lookup_matches(raise_without_backtrace_signature)
      unless matches.empty?
        raise_without_backtrace_def = matches.matches.not_nil!.first.def
        raise_without_backtrace_def.body = Primitive.new("repl_raise_without_backtrace")
      end
    end

    lib_instrinsics = program.types["LibIntrinsics"]?
    if lib_instrinsics
      %w(memcpy memmove memset debugtrap).each do |function_name|
        match = lib_instrinsics.lookup_first_def(function_name, false)
        match.body = Primitive.new("repl_intrinsics_#{function_name}") if match
      end
    end

    lib_m = program.types["LibM"]?
    if lib_m
      %w[32 64].each do |bits|
        %w[ceil cos exp exp2 log log2 log10].each do |function_name|
          match = lib_m.lookup_first_def("#{function_name}_f#{bits}", false)
          match.body = Primitive.new("repl_#{function_name}_f#{bits}") if match
        end
      end
    end
  end

  private def define_primitive_raise_without_backtrace
  end

  private def program
    @context.program
  end

  private def pry(ip, instructions, nodes, stack_bottom, stack)
    call_frame = @call_stack.last
    compiled_def = call_frame.compiled_def
    a_def = compiled_def.def
    local_vars = compiled_def.local_vars
    offset = (ip - instructions.to_unsafe).to_i32
    node = nodes[offset]?
    pry_node = @pry_node
    if node && (location = node.location) && different_node_line?(node, pry_node)
      whereami(a_def, location)

      # puts
      # puts Slice.new(stack_bottom, stack - stack_bottom).hexdump
      # puts

      # Remember the portion from stack_bottom + local_vars.max_bytesize up to stack
      # because it might happen that the child interpreter will overwrite some
      # of that if we already have some values in the stack past the local vars
      data_size = stack - (stack_bottom + local_vars.max_bytesize)
      data = Pointer(UInt8).malloc(data_size)
      data.copy_from(stack_bottom + local_vars.max_bytesize, data_size)

      interpreter = Interpreter.new(self, compiled_def, location, stack_bottom)

      while @pry
        print "pry> "
        line = gets
        unless line
          @pry = false
          @pry_node = nil
          break
        end

        case line
        when "continue"
          @pry = false
          @pry_node = nil
          @pry_max_target_frame = nil
          break
        when "step"
          @pry_node = node
          @pry_max_target_frame = nil
          break
        when "next"
          @pry_node = node
          @pry_max_target_frame = @call_stack.size
          break
        when "finish"
          @pry_node = node
          @pry_max_target_frame = @call_stack.size - 1
          break
        when "whereami"
          whereami(a_def, location)
          next
        when "disassemble"
          puts Disassembler.disassemble(compiled_def)
          next
        end

        begin
          parser = Parser.new(
            line,
            string_pool: @context.program.string_pool,
            def_vars: [interpreter.local_vars.names.to_set],
          )
          line_node = parser.parse

          value = interpreter.interpret(line_node)
          puts value
        rescue ex : Crystal::CodeError
          ex.color = true
          ex.error_trace = true
          puts ex
          next
        rescue ex : Exception
          ex.inspect_with_backtrace(STDOUT)
          next
        end
      end

      # Restore the stack data in case it tas overwritten
      (stack_bottom + local_vars.max_bytesize).copy_from(data, data_size)
    end
  end

  private def whereami(a_def : Def, location : Location)
    puts "From: #{location} #{a_def.owner}##{a_def.name}:"
    puts
    filename = location.filename
    case filename
    in String
      lines = File.read_lines(filename)
    in VirtualFile
      lines = filename.source.lines.to_a
    in Nil
      return
    end

    {location.line_number - 5, 1}.max.upto({location.line_number + 5, lines.size}.min) do |line_number|
      line = lines[line_number - 1]
      if line_number == location.line_number
        print " => "
      else
        print "    "
      end
      print line_number.colorize.blue
      print ": "
      puts SyntaxHighlighter.highlight(line)
    end
    puts
  end

  private def different_node_line?(node : ASTNode, previous_node : ASTNode?)
    return true unless previous_node
    return true if node.location.not_nil!.filename != previous_node.location.not_nil!.filename

    node.location.not_nil!.line_number != previous_node.location.not_nil!.line_number
  end
end

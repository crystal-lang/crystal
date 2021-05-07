require "./repl"
require "ffi"

class Crystal::Repl::Interpreter
  def initialize(program : Program)
    @program = program
    @local_vars = LocalVars.new(program)
    @dl_libraries = {} of String? => Void*
    @instructions = [] of Instruction

    # TODO: what if the stack is exhausted?
    @stack = uninitialized UInt8[8096]

    @main_visitor = MainVisitor.new(@program)
    @top_level_visitor = TopLevelVisitor.new(@program)
    @instructions_compiler = Compiler.new(@program, @local_vars)
  end

  def interpret(node : ASTNode) : Value
    node = @program.normalize(node)

    @top_level_visitor.reset
    node.accept @top_level_visitor

    @main_visitor.reset
    node.accept @main_visitor

    # Declare local variables
    # TODO: reuse previously declared variables
    @main_visitor.meta_vars.each do |name, meta_var|
      @local_vars.declare(name, meta_var.type)
    end

    @instructions = @instructions_compiler.compile(node)

    # puts Disassembler.disassemble(@instructions, @local_vars)

    # time = Time.monotonic
    value = interpret(node.type)
    # puts "Elapsed: #{Time.monotonic - time}"

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
    stack_bottom_after_local_vars = stack_bottom + @local_vars.total_size
    stack = stack_bottom_after_local_vars

    instructions = @instructions
    ip = instructions.to_unsafe

    while true
      # print @ip.to_s.rjust(4, '0')
      # print ' '

      op_code = next_instruction OpCode
      # puts op_code

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

      # p! @stack
    end

    return_value_size = @program.size_of(node_type.sizeof_type)
    return_value = Pointer(UInt8).malloc(return_value_size)
    return_value.copy_from(stack_bottom_after_local_vars, return_value_size)
    stack -= return_value_size
    if stack != stack_bottom_after_local_vars
      raise "BUG: data left on stack (#{stack - @stack.to_unsafe} bytes)"
    end

    Value.new(@program, return_value, node_type)
  end

  private macro set_ip(ip)
    ip = @instructions.to_unsafe + {{ip}}
  end

  private macro set_local_var(index, size)
    (stack - {{size}}).copy_to(stack_bottom + {{index}}, {{size}})
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

  private def literal_pointer(index)
    @literals.pointer(index)
  end

  private def literal_size(index)
    @literals.size(index)
  end

  private macro stack_pop(t)
    value = (stack - sizeof({{t}})).as({{t}}*).value
    stack_pop_size(sizeof({{t}}))
    value
  end

  private macro stack_pop_size(size)
    # TODO: clean up stack
    stack -= {{size}}
  end

  private macro stack_push(value)
    stack.as(Pointer(typeof({{value}}))).value = {{value}}
    stack += sizeof(typeof({{value}}))
  end

  private macro stack_copy_to(pointer, size)
    (stack - {{size}}).copy_to({{pointer}}, {{size}})
  end

  private macro stack_move_from(pointer, size)
    stack.copy_from({{pointer}}, {{size}})
    stack += {{size}}
  end

  private def sizeof_type(type : Type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end

  private def type_from_type_id(id : Int32) : Type
    @program.llvm_id.type_from_id(id)
  end
end

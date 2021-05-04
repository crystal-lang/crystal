require "./repl"
require "ffi"

class Crystal::Repl::Interpreter
  @def : Def?

  def initialize(program : Program)
    @program = program
    @scope = @program
    @def = nil
    @local_vars = LocalVars.new(program)
    @dl_libraries = {} of String? => Void*
    @stack = [] of UInt8
    @instructions = [] of Instruction
    @ip = 0

    @main_visitor = MainVisitor.new(@program)
    @top_level_visitor = TopLevelVisitor.new(@program)
    @instructions_compiler = Compiler.new(@program, @local_vars)
  end

  def interpret(node)
    @top_level_visitor.reset
    node.accept @top_level_visitor

    @main_visitor.reset
    node.accept @main_visitor

    @instructions = @instructions_compiler.compile(node)
    interpret

    return_value_size = @program.size_of(node.type.sizeof_type)
    return_value = Pointer(UInt8).malloc(return_value_size)
    return_value.copy_from(@stack.to_unsafe, return_value_size)
    @stack.clear

    return_value
  end

  def local_var_keys
    @local_vars.names
  end

  def interpret
    @stack.clear
    @ip = 0

    while true
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
                {{ pop_values[pop_values.size - i - 1] }} = stack_pop
              {% end %}

              {% if instruction[:push] %}
                stack_push({{instruction[:code]}})
              {% else %}
                {{instruction[:code]}}
              {% end %}
          {% end %}
        end
      {% end %}
    end
  end

  private def set_ip(@ip : Int32)
  end

  private def set_local_var(index, value)
    @local_vars[index] = value
  end

  private def get_local_var(index)
    @local_vars[index]
  end

  private def get_local_var_pointer(index)
    @local_vars.pointerof(index)
  end

  private def next_instruction(t : T.class) forall T
    value = (@instructions.to_unsafe + @ip).as(T*).value
    @ip += sizeof(T)
    value
  end

  private def literal_pointer(index)
    @literals.pointer(index)
  end

  private def literal_size(index)
    @literals.size(index)
  end

  private def stack_pop
    @stack.pop
  end

  private def stack_push(value : UInt16) : Nil
    value.unsafe_as(StaticArray(UInt8, 2)).each do |byte|
      stack_push byte
    end
  end

  private def stack_push(value : Int16) : Nil
    value.unsafe_as(StaticArray(UInt8, 2)).each do |byte|
      stack_push byte
    end
  end

  private def stack_push(value : Int8) : Nil
    stack_push(value.unsafe_as(UInt8))
  end

  private def stack_push(value : UInt8) : Nil
    @stack.push value
  end

  private def stack_last
    @stack.last
  end
end

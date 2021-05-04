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
    @stack = [] of Value
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

  private def set_local_var(index, value)
    @local_vars[index] = value
  end

  private def get_local_var(index)
    @local_vars[index]
  end

  private def next_instruction(t : Value.class)
    value = (@instructions.to_unsafe + @ip).as(Value*).value
    @ip += 2
    value
  end

  private def next_instruction(t : T.class) : T forall T
    value = @instructions[@ip].unsafe_as(T)
    @ip += 1
    value
  end

  private def stack_pop
    @stack.pop
  end

  private def stack_push(value)
    @stack.push value
  end

  private def stack_last
    @stack.last
  end

  # def visit(node : PointerOf)
  #   exp = node.exp
  #   case exp
  #   when Var
  #     @last = @local_vars.pointerof(exp.name)
  #   else
  #     node.raise "BUG: missing interpret for PointerOf with exp #{exp.class}"
  #   end
  #   false
  # end
end

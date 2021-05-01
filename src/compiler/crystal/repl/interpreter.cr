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
    @instructions_compiler = InstructionsCompiler.new(@program, @local_vars)
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
      case op_code
      in .put_nil?
        put_nil
      in .put_false?
        put_false
      in .put_true?
        put_true
      in .put_object?
        put_object
      in .set_local?
        set_local
      in .get_local?
        get_local
      in .dup?
        dup!
      in .binary_plus?
        binary_plus
      in .binary_minus?
        binary_minus
      in .binary_mult?
        binary_mult
      in .binary_lt?
        binary_lt
      in .binary_le?
        binary_le
      in .binary_gt?
        binary_gt
      in .binary_ge?
        binary_ge
      in .binary_eq?
        binary_eq
      in .binary_neq?
        binary_neq
      in .branch_unless?
        branch_unless
      in .leave?
        return @stack.pop
      end
    end
  end

  private def put_nil : Nil
    @stack.push Value.new(nil, @program.nil_type)
  end

  private def put_false : Nil
    @stack.push Value.new(false, @program.bool)
  end

  private def put_true : Nil
    @stack.push Value.new(true, @program.bool)
  end

  private def put_object : Nil
    value = next_instruction Pointer(Void)
    type = next_instruction Type
    @stack.push Value.new(value, type)
  end

  private def set_local : Nil
    index = next_instruction Int32
    value = @stack.pop
    @local_vars[index] = value
  end

  private def get_local : Nil
    index = next_instruction Int32
    @stack.push @local_vars[index]
  end

  private def dup! : Nil
    @stack.push @stack.last
  end

  private def binary_plus : Nil
    binary_int_of_float_op { |x, y| x + y }
  end

  private def binary_minus : Nil
    binary_int_of_float_op { |x, y| x - y }
  end

  private def binary_mult : Nil
    binary_int_of_float_op { |x, y| x * y }
  end

  private def binary_int_of_float_op : Nil
    right = @stack.pop
    left = @stack.pop

    result = yield(
      left.value.as(Int::Primitive | Float::Primitive),
      right.value.as(Int::Primitive | Float::Primitive),
    )
    type =
      case result
      when Int8    then @program.int8
      when UInt8   then @program.uint8
      when Int16   then @program.int16
      when UInt16  then @program.uint16
      when Int32   then @program.int32
      when UInt32  then @program.uint32
      when Int64   then @program.int64
      when UInt64  then @program.uint64
      when Float32 then @program.float32
      when Float64 then @program.float64
      else
        raise "Unexpected result type from binary op: #{result.class}"
      end
    @stack.push Value.new(result, type)
  end

  private def binary_lt : Nil
    binary_cmp { |x, y| x < y }
  end

  private def binary_le : Nil
    binary_cmp { |x, y| x <= y }
  end

  private def binary_gt : Nil
    binary_cmp { |x, y| x > y }
  end

  private def binary_ge : Nil
    binary_cmp { |x, y| x >= y }
  end

  private def binary_cmp : Nil
    right = @stack.pop
    left = @stack.pop

    result = yield(
      left.value.as(Int::Primitive | Float::Primitive),
      right.value.as(Int::Primitive | Float::Primitive),
    )

    @stack.push Value.new(result, @program.bool)
  end

  private def binary_eq : Nil
    right = @stack.pop
    left = @stack.pop

    @stack.push Value.new(left.value == right.value, @program.bool)
  end

  private def binary_neq : Nil
    right = @stack.pop
    left = @stack.pop

    @stack.push Value.new(left.value != right.value, @program.bool)
  end

  private def branch_unless : Nil
    index = next_instruction Int32

    cond = @stack.pop.value.as(Bool)
    unless cond
      @ip = index
    end
  end

  private def next_instruction(t : T.class) : T forall T
    value = @instructions[@ip].unsafe_as(T)
    @ip += 1
    value
  end

  # def visit(node : While)
  #   while true
  #     node.cond.accept self
  #     break unless @last.truthy?

  #     node.body.accept self
  #   end
  #   @last = Value.new(nil, @program.nil_type)
  #   false
  # end

  # def visit(node : Path)
  #   @last = Value.new(node.type.instance_type, node.type)
  #   false
  # end

  # def visit(node : Generic)
  #   @last = Value.new(node.type.instance_type, node.type)
  #   false
  # end

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

  # def visit(node : TypeOf)
  #   @last = Value.new(node.type, node.type.metaclass)
  #   false
  # end

  # def visit(node : Def)
  #   @last = Value.new(nil, @program.nil_type)
  #   super
  # end

  # def visit(node : ASTNode)
  #   node.raise "BUG: missing interpret for #{node.class}"
  # end
end

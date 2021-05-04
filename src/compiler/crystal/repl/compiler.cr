require "./repl"

class Crystal::Repl::Compiler < Crystal::Visitor
  alias Instruction = Int64

  def initialize(@program : Program, @local_vars : LocalVars)
    @instructions = [] of Instruction
  end

  def compile(node : ASTNode) : Array(Instruction)
    @instructions.clear

    node.accept self

    leave

    puts disassemble(@instructions)

    @instructions
  end

  def visit(node : Nop)
    put_nil
    false
  end

  def visit(node : NilLiteral)
    put_nil
    false
  end

  def visit(node : BoolLiteral)
    node.value ? put_true : put_false
    false
  end

  def visit(node : CharLiteral)
    put_object node.value.ord, node.type
    false
  end

  def visit(node : NumberLiteral)
    case node.kind
    when :i8
      put_object node.value.to_i8, node.type
    when :u8
      put_object node.value.to_u8, node.type
    when :i16
      put_object node.value.to_i16, node.type
    when :u16
      put_object node.value.to_u16, node.type
    when :i32
      put_object node.value.to_i32, node.type
    when :u32
      put_object node.value.to_u32, node.type
    when :i64
      put_object node.value.to_i64, node.type
    when :u64
      put_object node.value.to_u64, node.type
    when :f32
      put_object node.value.to_f32, node.type
    when :f64
      put_object node.value.to_f64, node.type
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
    false
  end

  def visit(node : StringLiteral)
    put_object node.value.object_id, node.type
    false
  end

  def visit(node : Expressions)
    node.expressions.each_with_index do |expression, i|
      expression.accept self
      pop if i < node.expressions.size - 1
    end
    false
  end

  def visit(node : Assign)
    target = node.target
    case target
    when Var
      node.value.accept self
      index = @local_vars.name_to_index(target.name)
      set_local index
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  def visit(node : Var)
    index = @local_vars.name_to_index(node.name)
    get_local index
    false
  end

  def visit(node : If)
    node.cond.accept self
    branch_unless 0
    cond_jump_location = patch_location

    node.then.accept self
    jump 0
    then_jump_location = patch_location

    patch_jump(cond_jump_location)

    node.else.accept self

    patch_jump(then_jump_location)

    false
  end

  def visit(node : While)
    jump 0
    cond_jump_location = patch_location

    body_index = @instructions.size
    node.body.accept self

    patch_jump(cond_jump_location)

    node.cond.accept self
    branch_if body_index

    put_nil

    false
  end

  def visit(node : TypeOf)
    put_object node.type.object_id, node.type.metaclass
    false
  end

  def visit(node : Path)
    put_object node.type.object_id, node.type.metaclass
    false
  end

  def visit(node : Generic)
    put_object node.type.object_id, node.type.metaclass
    false
  end

  def visit(node : Call)
    # TODO: handle case of multidispatch
    target_def = node.target_def

    node.obj.try &.accept(self)
    node.args.each &.accept(self)

    # TODO: named arguments

    body = target_def.body
    if body.is_a?(Primitive)
      visit_primitive(node, body)
      return false
    else
      node.raise "BUG: missing handling of non-primitive call"
    end

    # arg_values = node.args.map do |arg|
    #   visit(arg)
    #   @last
    # end

    # named_arg_values =
    #   if named_args = node.named_args
    #     named_args.map do |named_arg|
    #       named_arg.value.accept self
    #       {named_arg.name, @last}
    #     end
    #   else
    #     nil
    #   end

    # old_scope, @scope = scope, target_def.owner
    # old_local_vars, @local_vars = @local_vars, LocalVars.new
    # @def = target_def

    # if obj_value && obj_value.type.is_a?(LibType)
    #   # Okay... we need to d a C call. libffi to the rescue!
    #   handle = @dl_libraries[nil] ||= LibC.dlopen(nil, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
    #   fn = LibC.dlsym(handle, node.name)
    #   if fn.null?
    #     node.raise "dlsym failed for #{node.name}"
    #   end

    #   # TODO: missing named arguments here
    #   cif = FFI.prepare(
    #     abi: FFI::ABI::DEFAULT,
    #     args: arg_values.map(&.type.ffi_type),
    #     return_type: node.type.ffi_type,
    #   )

    #   pointers = [] of Void*
    #   arg_values.each do |arg_value|
    #     pointer = Pointer(Void).malloc(@program.size_of(arg_value.type.sizeof_type))
    #     arg_value.ffi_value(pointer)
    #     pointers << pointer
    #   end

    #   cif.call(fn, pointers)

    #   # TODO: missing return value
    # else
    #   # Set up local vars for the def instatiation
    #   if obj_value
    #     @local_vars["self"] = obj_value
    #   end

    #   arg_values.zip(target_def.args) do |arg_value, def_arg|
    #     @local_vars[def_arg.name] = arg_value
    #   end

    #   if named_arg_values
    #     named_arg_values.each do |name, value|
    #       @local_vars[name] = value
    #     end
    #   end

    #   target_def.body.accept self
    # end

    # @scope = old_scope
    # @local_vars = old_local_vars
    # @def = nil

    false
  end

  private def visit_primitive(node, body)
    case body.name
    when "binary"
      case node.name
      when "+"  then binary_plus
      when "-"  then binary_minus
      when "*"  then binary_mult
      when "<"  then binary_lt
      when "<=" then binary_le
      when ">"  then binary_gt
      when ">=" then binary_ge
      when "==" then binary_eq
      when "!=" then binary_neq
      else
        node.raise "BUG: missing handling of binary op #{node.name}"
      end
    when "pointer_malloc"
      pointer_malloc
    when "pointer_set"
      pointer_set
    when "pointer_get"
      pointer_get
    else
      puts disassemble(@instructions)

      node.raise "BUG: missing handling of primitive #{body.name}"
    end
  end

  private def pointer_malloc
    append OpCode::POINTER_MALLOC
  end

  private def pointer_set
    append OpCode::POINTER_SET
  end

  private def pointer_get
    append OpCode::POINTER_GET
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing instruction compiler for #{node.class}"
  end

  private def put_nil : Nil
    append OpCode::PUT_NIL
  end

  private def put_false : Nil
    append OpCode::PUT_FALSE
  end

  private def put_true : Nil
    append OpCode::PUT_TRUE
  end

  private def put_object(value, type : Type) : Nil
    append OpCode::PUT_OBJECT
    append value.unsafe_as(Int64)
    append type
  end

  private def set_local(index : Int32) : Nil
    append OpCode::SET_LOCAL
    append index
  end

  private def get_local(index : Int32) : Nil
    append OpCode::GET_LOCAL
    append index
  end

  private def leave
    append OpCode::LEAVE
  end

  private def binary_plus
    append OpCode::BINARY_PLUS
  end

  private def binary_minus
    append OpCode::BINARY_MINUS
  end

  private def binary_mult
    append OpCode::BINARY_MULT
  end

  private def binary_lt
    append OpCode::BINARY_LT
  end

  private def binary_le
    append OpCode::BINARY_LE
  end

  private def binary_gt
    append OpCode::BINARY_GT
  end

  private def binary_ge
    append OpCode::BINARY_GE
  end

  private def binary_eq
    append OpCode::BINARY_EQ
  end

  private def binary_neq
    append OpCode::BINARY_NEQ
  end

  private def branch_if(index)
    append OpCode::BRANCH_IF
    append index
  end

  private def branch_unless(index)
    append OpCode::BRANCH_UNLESS
    append index
  end

  private def jump(index)
    append OpCode::JUMP
    append index
  end

  private def pop
    append OpCode::POP
  end

  private def append(op_code : OpCode)
    append op_code.value
  end

  private def append(value : Int32)
    append value.to_i64!
  end

  private def append(value : Int64)
    @instructions << value
  end

  private def append(type : Type)
    append type.object_id.unsafe_as(Int64)
  end

  private def patch_location
    @instructions.size - 1
  end

  private def patch_jump(offset)
    @instructions[offset] = @instructions.size.to_i64!
  end

  private def disassemble(instructions : Array(Instruction)) : String
    String.build do |io|
      ip = 0
      while ip < instructions.size
        io.print ip.to_s.rjust(4, '0')
        io.print ' '
        op_code, ip = next_instruction instructions, ip, OpCode

        case op_code
        in .put_nil?
          io.puts "put_nil"
        in .put_false?
          io.puts "put_false"
        in .put_true?
          io.puts "put_true"
        in .put_object?
          io.print "put_object "
          value, ip = next_instruction instructions, ip, Pointer(Void)
          type, ip = next_instruction instructions, ip, Type
          repl_value = Value.new(value, type)
          io.print repl_value.value.inspect
          io.print " ("
          io.print repl_value.type
          io.puts ")"
        in .set_local?
          io.print "set_local "
          index, ip = next_instruction instructions, ip, Int32
          name = @local_vars.index_to_name(index)
          io.print name
          io.print '@'
          io.puts index
        in .get_local?
          io.print "get_local "
          index, ip = next_instruction instructions, ip, Int32
          name = @local_vars.index_to_name(index)
          io.print name
          io.print '@'
          io.puts index
        in .binary_plus?
          io.puts "binary_plus"
        in .binary_minus?
          io.puts "binary_minus"
        in .binary_mult?
          io.puts "binary_mult"
        in .binary_lt?
          io.puts "binary_lt"
        in .binary_le?
          io.puts "binary_le"
        in .binary_gt?
          io.puts "binary_gt"
        in .binary_ge?
          io.puts "binary_ge"
        in .binary_eq?
          io.puts "binary_eq"
        in .binary_neq?
          io.puts "binary_neq"
        in .branch_if?
          index, ip = next_instruction instructions, ip, Int32
          io.print "branch_if "
          io.puts index
        in .branch_unless?
          index, ip = next_instruction instructions, ip, Int32
          io.print "branch_unless "
          io.puts index
        in .jump?
          index, ip = next_instruction instructions, ip, Int32
          io.print "jump "
          io.puts index
        in .pop?
          io.puts "pop"
        in .pointer_malloc?
          io.puts "pointer_malloc"
        in .pointer_set?
          io.puts "pointer_set"
        in .pointer_get?
          io.puts "pointer_get"
        in .leave?
          io.puts "leave"
        end
      end
    end
  end

  private def next_instruction(instructions, ip, t : T.class) forall T
    value = instructions[ip].unsafe_as(T)
    ip += 1
    {value, ip}
  end
end

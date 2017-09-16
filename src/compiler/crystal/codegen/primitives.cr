require "./codegen"

class Crystal::CodeGenVisitor
  # Can only happen in a Const or as an argument cast.
  def visit(node : Primitive)
    @last = case node.name
            when "argc"
              @argc
            when "argv"
              @argv
            else
              raise "BUG: unhandled primitive in codegen visit: #{node.name}"
            end
  end

  def codegen_primitive(call, node, target_def, call_args)
    @last = case node.name
            when "binary"
              codegen_primitive_binary node, target_def, call_args
            when "cast"
              codegen_primitive_cast node, target_def, call_args
            when "allocate"
              codegen_primitive_allocate node, target_def, call_args
            when "pointer_malloc"
              codegen_primitive_pointer_malloc node, target_def, call_args
            when "pointer_set"
              codegen_primitive_pointer_set node, target_def, call_args
            when "pointer_get"
              codegen_primitive_pointer_get node, target_def, call_args
            when "pointer_address"
              codegen_primitive_pointer_address node, target_def, call_args
            when "pointer_new"
              codegen_primitive_pointer_new node, target_def, call_args
            when "pointer_realloc"
              codegen_primitive_pointer_realloc node, target_def, call_args
            when "pointer_add"
              codegen_primitive_pointer_add node, target_def, call_args
            when "pointer_diff"
              codegen_primitive_pointer_diff node, target_def, call_args
            when "struct_or_union_set"
              codegen_primitive_struct_or_union_set node, target_def, call_args
            when "external_var_set"
              codegen_primitive_external_var_set node, target_def, call_args
            when "external_var_get"
              codegen_primitive_external_var_get node, target_def, call_args
            when "object_id"
              codegen_primitive_object_id node, target_def, call_args
            when "object_crystal_type_id"
              codegen_primitive_object_crystal_type_id node, target_def, call_args
            when "class_crystal_instance_type_id"
              codegen_primitive_class_crystal_instance_type_id node, target_def, call_args
            when "symbol_to_s"
              codegen_primitive_symbol_to_s node, target_def, call_args
            when "class"
              codegen_primitive_class node, target_def, call_args
            when "proc_call"
              codegen_primitive_proc_call node, target_def, call_args
            when "tuple_indexer_known_index"
              codegen_primitive_tuple_indexer_known_index node, target_def, call_args
            when "enum_value", "enum_new"
              call_args[0]
            when "cmpxchg"
              codegen_primitive_cmpxchg call, node, target_def, call_args
            when "atomicrmw"
              codegen_primitive_atomicrmw call, node, target_def, call_args
            when "fence"
              codegen_primitive_fence call, node, target_def, call_args
            when "load_atomic"
              codegen_primitive_load_atomic call, node, target_def, call_args
            when "store_atomic"
              codegen_primitive_store_atomic call, node, target_def, call_args
            else
              raise "BUG: unhandled primitive in codegen: #{node.name}"
            end
  end

  def codegen_primitive_binary(node, target_def, call_args)
    p1, p2 = call_args
    t1, t2 = target_def.owner, target_def.args[0].type
    codegen_binary_op target_def.name, t1, t2, p1, p2
  end

  def codegen_binary_op(op, t1 : BoolType, t2 : BoolType, p1, p2)
    case op
    when "==" then builder.icmp LLVM::IntPredicate::EQ, p1, p2
    when "!=" then builder.icmp LLVM::IntPredicate::NE, p1, p2
    else           raise "BUG: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op(op, t1 : CharType, t2 : CharType, p1, p2)
    case op
    when "==" then return builder.icmp LLVM::IntPredicate::EQ, p1, p2
    when "!=" then return builder.icmp LLVM::IntPredicate::NE, p1, p2
    when "<"  then return builder.icmp LLVM::IntPredicate::ULT, p1, p2
    when "<=" then return builder.icmp LLVM::IntPredicate::ULE, p1, p2
    when ">"  then return builder.icmp LLVM::IntPredicate::UGT, p1, p2
    when ">=" then return builder.icmp LLVM::IntPredicate::UGE, p1, p2
    else           raise "BUG: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op(op, t1 : SymbolType, t2 : SymbolType, p1, p2)
    case op
    when "==" then return builder.icmp LLVM::IntPredicate::EQ, p1, p2
    when "!=" then return builder.icmp LLVM::IntPredicate::NE, p1, p2
    else           raise "BUG: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op(op, t1 : IntegerType, t2 : IntegerType, p1, p2)
    # Comparisons are a bit trickier because we want to get comparisons
    # between signed and unsigned integers right.
    case op
    when "<"  then return @last = codegen_binary_op_lt(t1, t2, p1, p2)
    when "<=" then return @last = codegen_binary_op_lte(t1, t2, p1, p2)
    when ">"  then return @last = codegen_binary_op_gt(t1, t2, p1, p2)
    when ">=" then return @last = codegen_binary_op_gte(t1, t2, p1, p2)
    end

    p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)

    @last = case op
            when "+"               then builder.add p1, p2
            when "-"               then builder.sub p1, p2
            when "*"               then builder.mul p1, p2
            when "/", "unsafe_div" then t1.signed? ? builder.sdiv(p1, p2) : builder.udiv(p1, p2)
            when "%", "unsafe_mod" then t1.signed? ? builder.srem(p1, p2) : builder.urem(p1, p2)
            when "unsafe_shl"      then builder.shl(p1, p2)
            when "unsafe_shr"      then t1.signed? ? builder.ashr(p1, p2) : builder.lshr(p1, p2)
            when "|"               then or(p1, p2)
            when "&"               then and(p1, p2)
            when "^"               then builder.xor(p1, p2)
            when "=="              then return builder.icmp LLVM::IntPredicate::EQ, p1, p2
            when "!="              then return builder.icmp LLVM::IntPredicate::NE, p1, p2
            else                        raise "BUG: trying to codegen #{t1} #{op} #{t2}"
            end

    if t1.normal_rank != t2.normal_rank && t1.rank < t2.rank
      @last = trunc @last, llvm_type(t1)
    end

    @last
  end

  def codegen_binary_extend_int(t1, t2, p1, p2)
    if t1.normal_rank == t2.normal_rank
      # Nothing to do
    elsif t1.rank < t2.rank
      p1 = extend_int t1, t2, p1
    else
      p2 = extend_int t2, t1, p2
    end
    {p1, p2}
  end

  def codegen_binary_op_lt(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SLT : LLVM::IntPredicate::ULT), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x < 0 || x < x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SLT, p1, extend_int(t2, t1, p2))
          )
        else
          # x < 0 || y.class.new(x) < y
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::ULT, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y >= 0 && y.class.new(x) < y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SLT, extend_int(t1, t2, p1), p2)
          )
        else
          # y >= 0 && x < x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::ULT, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op_lte(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SLE : LLVM::IntPredicate::ULE), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x <= 0 || x <= x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SLE, p1, extend_int(t2, t1, p2))
          )
        else
          # x <= 0 || y.class.new(x) <= y
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::ULE, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y >= 0 && y.class.new(x) <= y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SLE, extend_int(t1, t2, p1), p2)
          )
        else
          # y >= 0 && x <= x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::ULE, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op_gt(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SGT : LLVM::IntPredicate::UGT), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x >= 0 && x > x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SGT, p1, extend_int(t2, t1, p2))
          )
        else
          # x >= 0 && y.class.new(x) > y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::UGT, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y < 0 || y.class.new(x) > y
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SGT, extend_int(t1, t2, p1), p2)
          )
        else
          # y < 0 || x > x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLT, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::UGT, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op_gte(t1, t2, p1, p2)
    if t1.signed? == t2.signed?
      p1, p2 = codegen_binary_extend_int(t1, t2, p1, p2)
      builder.icmp (t1.signed? ? LLVM::IntPredicate::SGE : LLVM::IntPredicate::UGE), p1, p2
    else
      if t1.signed? && t2.unsigned?
        if t1.bytes > t2.bytes
          # x >= 0 && x >= x.class.new(y)
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::SGE, p1, extend_int(t2, t1, p2))
          )
        else
          # x >= 0 && y.class.new(x) >= y
          and(
            builder.icmp(LLVM::IntPredicate::SGE, p1, int(0, t1)),
            builder.icmp(LLVM::IntPredicate::UGE, extend_int(t1, t2, p1), p2)
          )
        end
      else
        # t1.unsigned? && t2.signed?
        if t1.bytes < t2.bytes
          # y <= 0 || y.class.new(x) >= y
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::SGE, extend_int(t1, t2, p1), p2)
          )
        else
          # y <= 0 || x >= x.class.new(y)
          or(
            builder.icmp(LLVM::IntPredicate::SLE, p2, int(0, t2)),
            builder.icmp(LLVM::IntPredicate::UGE, p1, extend_int(t2, t1, p2))
          )
        end
      end
    end
  end

  def codegen_binary_op(op, t1 : IntegerType, t2 : FloatType, p1, p2)
    p1 = codegen_cast(t1, t2, p1)
    codegen_binary_op(op, t2, t2, p1, p2)
  end

  def codegen_binary_op(op, t1 : FloatType, t2 : IntegerType, p1, p2)
    p2 = codegen_cast(t2, t1, p2)
    codegen_binary_op op, t1, t1, p1, p2
  end

  def codegen_binary_op(op, t1 : FloatType, t2 : FloatType, p1, p2)
    if t1.rank < t2.rank
      p1 = extend_float t2, p1
    elsif t1.rank > t2.rank
      p2 = extend_float t1, p2
    end

    @last = case op
            when "+"  then builder.fadd p1, p2
            when "-"  then builder.fsub p1, p2
            when "*"  then builder.fmul p1, p2
            when "/"  then builder.fdiv p1, p2
            when "==" then return builder.fcmp LLVM::RealPredicate::OEQ, p1, p2
            when "!=" then return builder.fcmp LLVM::RealPredicate::ONE, p1, p2
            when "<"  then return builder.fcmp LLVM::RealPredicate::OLT, p1, p2
            when "<=" then return builder.fcmp LLVM::RealPredicate::OLE, p1, p2
            when ">"  then return builder.fcmp LLVM::RealPredicate::OGT, p1, p2
            when ">=" then return builder.fcmp LLVM::RealPredicate::OGE, p1, p2
            else           raise "BUG: trying to codegen #{t1} #{op} #{t2}"
            end
    @last = trunc_float t1, @last if t1.rank < t2.rank
    @last
  end

  def codegen_binary_op(op, t1 : TypeDefType, t2, p1, p2)
    codegen_binary_op op, t1.remove_typedef, t2, p1, p2
  end

  def codegen_binary_op(op, t1, t2, p1, p2)
    raise "BUG: codegen_binary_op called with #{t1} #{op} #{t2}"
  end

  def codegen_primitive_cast(node, target_def, call_args)
    p1 = call_args[0]
    from_type, to_type = target_def.owner, target_def.type
    codegen_cast from_type, to_type, p1
  end

  def codegen_cast(from_type : IntegerType, to_type : IntegerType, arg)
    if from_type.normal_rank == to_type.normal_rank
      arg
    elsif from_type.rank < to_type.rank
      extend_int from_type, to_type, arg
    else
      trunc arg, llvm_type(to_type)
    end
  end

  def codegen_cast(from_type : IntegerType, to_type : FloatType, arg)
    int_to_float from_type, to_type, arg
  end

  def codegen_cast(from_type : FloatType, to_type : IntegerType, arg)
    float_to_int from_type, to_type, arg
  end

  def codegen_cast(from_type : FloatType, to_type : FloatType, arg)
    if from_type.rank < to_type.rank
      extend_float to_type, arg
    elsif from_type.rank > to_type.rank
      trunc_float to_type, arg
    else
      arg
    end
  end

  def codegen_cast(from_type : IntegerType, to_type : CharType, arg)
    codegen_cast from_type, @program.int32, arg
  end

  def codegen_cast(from_type : CharType, to_type : IntegerType, arg)
    builder.zext arg, llvm_type(to_type)
  end

  def codegen_cast(from_type : SymbolType, to_type : IntegerType, arg)
    arg
  end

  def codegen_cast(from_type : TypeDefType, to_type, arg)
    codegen_cast from_type.remove_typedef, to_type, arg
  end

  def codegen_cast(from_type, to_type, arg)
    raise "BUG: codegen_cast called from #{from_type} to #{to_type}"
  end

  def codegen_primitive_allocate(node, target_def, call_args)
    type = node.type
    base_type = type.is_a?(VirtualType) ? type.base_type : type

    allocate_aggregate base_type

    unless type.struct?
      type_id_ptr = aggregate_index(@last, 0)
      store type_id(base_type), type_id_ptr
    end

    if type.is_a?(VirtualType)
      @last = upcast(@last, type, base_type)
    end

    @last
  end

  def codegen_primitive_pointer_malloc(node, target_def, call_args)
    type = node.type.as(PointerInstanceType)
    llvm_type = llvm_embedded_type(type.element_type)

    old_debug_location = @current_debug_location
    if @debug.line_numbers? && (location = node.location)
      set_current_debug_location(node.location)
    end

    if type.element_type.has_inner_pointers?
      last = array_malloc(llvm_type, call_args[1])
    else
      last = array_malloc_atomic(llvm_type, call_args[1])
    end

    if @debug.line_numbers?
      set_current_debug_location(old_debug_location)
    end

    last
  end

  def codegen_primitive_pointer_set(node, target_def, call_args)
    type = context.type.remove_typedef.as(PointerInstanceType)

    # Assinging to a Pointer(Void) has no effect
    return llvm_nil if type.element_type.void?

    value = call_args[1]
    assign call_args[0], type.element_type, node.type, value
    value
  end

  def codegen_primitive_pointer_get(node, target_def, call_args)
    type = context.type.remove_typedef.as(PointerInstanceType)
    to_lhs call_args[0], type.element_type
  end

  def codegen_primitive_pointer_address(node, target_def, call_args)
    ptr2int call_args[0], llvm_context.int64
  end

  def codegen_primitive_pointer_new(node, target_def, call_args)
    int2ptr(call_args[1], llvm_type(node.type))
  end

  def codegen_primitive_pointer_realloc(node, target_def, call_args)
    type = context.type.as(PointerInstanceType)

    casted_ptr = cast_to_void_pointer(call_args[0])
    size = builder.mul call_args[1], llvm_size(type.element_type)
    reallocated_ptr = realloc casted_ptr, size
    cast_to_pointer reallocated_ptr, type.element_type
  end

  def codegen_primitive_pointer_add(node, target_def, call_args)
    gep call_args[0], call_args[1]
  end

  def struct_field_ptr(type, field_name, pointer)
    index = type.index_of_instance_var('@' + field_name).not_nil!
    aggregate_index pointer, index
  end

  def codegen_primitive_struct_or_union_set(node, target_def, call_args)
    set_aggregate_field(node, target_def, call_args) do |field_type|
      type = context.type.as(NonGenericClassType)
      if type.extern_union?
        union_field_ptr(field_type, call_args[0])
      else
        name = target_def.name.rchop
        struct_field_ptr(type, name, call_args[0])
      end
    end
  end

  def set_aggregate_field(node, target_def, call_args)
    call_arg = call_args[1]
    original_call_arg = call_arg

    # Check if we need to do a numeric conversion
    if (extra = node.extra)
      existing_value = context.vars["value"]?
      context.vars["value"] = LLVMVar.new(call_arg, node.type, true)
      request_value { extra.accept self }
      call_arg = @last
      context.vars["value"] = existing_value if existing_value
    end

    var_name = '@' + target_def.name.rchop
    scope = context.type.as(NonGenericClassType)
    field_type = scope.instance_vars[var_name].type

    # Check nil to pointer
    if node.type.nil_type? && (field_type.pointer? || field_type.proc?)
      call_arg = llvm_c_type(field_type).null
    end

    if field_type.proc?
      call_arg = check_proc_is_not_closure(call_arg, field_type)
    end

    value = to_rhs call_arg, field_type
    store value, yield(field_type)

    original_call_arg
  end

  def union_field_ptr(field_type, pointer)
    ptr = aggregate_index pointer, 0
    if field_type.is_a?(ProcInstanceType)
      bit_cast ptr, @llvm_typer.proc_type(field_type).pointer
    else
      cast_to_pointer ptr, field_type
    end
  end

  def codegen_primitive_external_var_set(node, target_def, call_args)
    external = target_def.as(External)
    name = external.real_name
    var = declare_lib_var name, node.type, external.thread_local?

    @last = call_args[0]

    if external.type.passed_by_value?
      @last = load @last
    end

    store @last, var

    @last = check_c_fun node.type, @last

    @last
  end

  def codegen_primitive_external_var_get(node, target_def, call_args)
    external = target_def.as(External)
    name = target_def.as(External).real_name
    var = declare_lib_var name, node.type, external.thread_local?

    if external.type.passed_by_value?
      @last = var
    else
      @last = load var
    end

    @last = check_c_fun node.type, @last

    @last
  end

  def codegen_primitive_object_id(node, target_def, call_args)
    ptr2int call_args[0], llvm_context.int64
  end

  def codegen_primitive_object_crystal_type_id(node, target_def, call_args)
    if context.type.is_a?(MetaclassType)
      type_id(type)
    else
      type_id(call_args[0], type)
    end
  end

  def codegen_primitive_class_crystal_instance_type_id(node, target_def, call_args)
    type_id(context.type.instance_type)
  end

  def codegen_primitive_symbol_to_s(node, target_def, call_args)
    load(gep @llvm_mod.globals[SYMBOL_TABLE_NAME], int(0), call_args[0])
  end

  def codegen_primitive_class(node, target_def, call_args)
    value = call_args.first?
    if value
      codegen_primitive_class_with_type(type, value)
    else
      type_id(node.type)
    end
  end

  def codegen_primitive_class_with_type(type : VirtualType, value)
    type_id = type_id(value, type)
    metaclass_fun_name = "~metaclass"
    func = @main_mod.functions[metaclass_fun_name]? || create_metaclass_fun(metaclass_fun_name)
    func = check_main_fun metaclass_fun_name, func
    call func, [type_id] of LLVM::Value
  end

  def create_metaclass_fun(name)
    id_to_metaclass = @llvm_id.id_to_metaclass.to_a.sort_by! &.[0]

    in_main do
      define_main_function(name, ([llvm_context.int32]), llvm_context.int32) do |func|
        arg = func.params.first

        current_block = insert_block

        cases = {} of LLVM::Value => LLVM::BasicBlock
        id_to_metaclass.each do |(type_id, metaclass_id)|
          block = new_block "type_#{type_id}"
          cases[int32(type_id)] = block
          position_at_end block
          ret int32(metaclass_id)
        end

        otherwise = new_block "otherwise"
        position_at_end otherwise
        unreachable

        position_at_end current_block
        @builder.switch arg, otherwise, cases
      end
    end
  end

  def codegen_primitive_class_with_type(type : Type, value)
    type_id(type.metaclass)
  end

  def codegen_primitive_proc_call(node, target_def, call_args)
    closure_ptr = call_args[0]

    # For non-closure args we use byval attribute and other things
    # that the C ABI dictates, if needed (args).
    # Otherwise we load the values (closure_args).
    args = call_args[1..-1]
    closure_args = Array(LLVM::Value).new(args.size + 1)

    c_calling_convention = target_def.proc_c_calling_convention?

    proc_type = context.type.as(ProcInstanceType)
    target_def.args.size.times do |i|
      arg = args[i]
      proc_arg_type = proc_type.arg_types[i]
      target_def_arg_type = target_def.args[i].type
      args[i] = upcast arg, proc_arg_type, target_def_arg_type
      if proc_arg_type.passed_by_value?
        closure_args << load(args[i])
      else
        closure_args << args[i]
      end
    end

    fun_ptr = builder.extract_value closure_ptr, 0
    ctx_ptr = builder.extract_value closure_ptr, 1

    ctx_is_null_block = new_block "ctx_is_null"
    ctx_is_not_null_block = new_block "ctx_is_not_null"

    ctx_is_null = equal? ctx_ptr, llvm_context.void_pointer.null
    cond ctx_is_null, ctx_is_null_block, ctx_is_not_null_block

    old_needs_value = @needs_value
    @needs_value = true

    phi_value = Phi.open(self, node, @needs_value) do |phi|
      position_at_end ctx_is_null_block
      real_fun_ptr = bit_cast fun_ptr, llvm_proc_type(context.type)

      # When invoking a Proc that has extern structs as arguments or return type, it's tricky:
      # closures are never generated with C ABI because C doesn't support closures.
      # But non-closures use C ABI, so if the target Proc is not a closure we cast the
      # arguments according to the ABI.
      # For this we temporarily set the target_def's `abi_info` and `c_calling_convention`
      # properties for the non-closure branch, and then reset it.
      old_abi_info = target_def.abi_info?
      old_c_calling_convention = target_def.c_calling_convention

      if c_calling_convention
        null_fun_ptr, null_args = codegen_extern_primitive_proc_call(target_def, args, fun_ptr)
      else
        null_fun_ptr, null_args = real_fun_ptr, closure_args
      end

      value = codegen_call_or_invoke(node, target_def, nil, null_fun_ptr, null_args, true, target_def.type, false, proc_type)
      phi.add value, node.type

      # Reset abi_info + c_calling_convention so the closure part is generated as usual
      target_def.abi_info = false
      target_def.c_calling_convention = nil

      position_at_end ctx_is_not_null_block
      real_fun_ptr = bit_cast fun_ptr, llvm_closure_type(context.type)
      closure_args.insert(0, ctx_ptr)
      value = codegen_call_or_invoke(node, target_def, nil, real_fun_ptr, closure_args, true, target_def.type, true, proc_type)
      phi.add value, node.type, true

      target_def.abi_info = old_abi_info
      target_def.c_calling_convention = old_c_calling_convention
    end

    old_needs_value = @needs_value
    phi_value
  end

  def codegen_extern_primitive_proc_call(target_def, args, fun_ptr)
    null_fun_types = [] of LLVM::Type

    null_args = [] of LLVM::Value
    abi_info = abi_info(target_def)

    if abi_info.return_type.attr == LLVM::Attribute::StructRet
      sret_value = @sret_value = alloca abi_info.return_type.type
      null_args << sret_value
      null_fun_types << abi_info.return_type.type.pointer
      null_fun_return_type = llvm_context.void
    else
      if cast = abi_info.return_type.cast
        null_fun_return_type = cast
      else
        null_fun_return_type = abi_info.return_type.type
      end
    end

    target_def.args.each_with_index do |arg, index|
      call_arg = args[index]

      abi_arg_type = abi_info.arg_types[index]
      case abi_arg_type.kind
      when LLVM::ABI::ArgKind::Direct
        call_arg = codegen_direct_abi_call(call_arg, abi_arg_type)
        if cast = abi_arg_type.cast
          null_fun_types << cast
        else
          null_fun_types << abi_arg_type.type
        end
        null_args << call_arg
      when LLVM::ABI::ArgKind::Indirect
        # Pass argument as is (will be passed byval)
        null_args << call_arg
        null_fun_types << abi_arg_type.type.pointer
      when LLVM::ABI::ArgKind::Ignore
        # Ignore
      end
    end

    null_fun_llvm_type = LLVM::Type.function(null_fun_types, null_fun_return_type)
    null_fun_ptr = bit_cast fun_ptr, null_fun_llvm_type.pointer
    target_def.c_calling_convention = true

    {null_fun_ptr, null_args}
  end

  def codegen_primitive_pointer_diff(node, target_def, call_args)
    p0 = ptr2int(call_args[0], llvm_context.int64)
    p1 = ptr2int(call_args[1], llvm_context.int64)
    sub = builder.sub p0, p1
    builder.exact_sdiv sub, ptr2int(gep(call_args[0].type.null_pointer, 1), llvm_context.int64)
  end

  def codegen_primitive_tuple_indexer_known_index(node, target_def, call_args)
    index = node.as(TupleIndexer).index
    codegen_tuple_indexer(context.type, call_args[0], index)
  end

  def codegen_tuple_indexer(type, value, index)
    case type
    when TupleInstanceType
      ptr = aggregate_index value, index
      to_lhs ptr, type.tuple_types[index]
    when NamedTupleInstanceType
      ptr = aggregate_index value, index
      to_lhs ptr, type.entries[index].type
    else
      type = type.instance_type
      case type
      when TupleInstanceType
        type_id(type.tuple_types[index].as(Type).metaclass)
      when NamedTupleInstanceType
        type_id(type.entries[index].type.as(Type).metaclass)
      else
        raise "BUG: unsupported codegen for tuple_indexer"
      end
    end
  end

  def check_c_fun(type, value)
    if type.proc?
      make_fun(type, bit_cast(value, llvm_context.void_pointer), llvm_context.void_pointer.null)
    else
      value
    end
  end

  def codegen_primitive_cmpxchg(call, node, target_def, call_args)
    success_ordering = atomic_ordering_from_symbol_literal(call.args[-2])
    failure_ordering = atomic_ordering_from_symbol_literal(call.args[-1])

    pointer, cmp, new = call_args
    value = builder.cmpxchg(pointer, cmp, new, success_ordering, failure_ordering)
    value_ptr = alloca llvm_type(node.type)
    store extract_value(value, 0), gep(value_ptr, 0, 0)
    store extract_value(value, 1), gep(value_ptr, 0, 1)
    value_ptr
  end

  def codegen_primitive_atomicrmw(call, node, target_def, call_args)
    op = atomicrwm_bin_op_from_symbol_literal(call.args[0])
    ordering = atomic_ordering_from_symbol_literal(call.args[-2])
    singlethread = bool_from_bool_literal(call.args[-1])

    _, pointer, val = call_args
    builder.atomicrmw(op, pointer, val, ordering, singlethread)
  end

  def codegen_primitive_fence(call, node, target_def, call_args)
    ordering = atomic_ordering_from_symbol_literal(call.args[0])
    singlethread = bool_from_bool_literal(call.args[1])

    builder.fence(ordering, singlethread)
    llvm_nil
  end

  def codegen_primitive_load_atomic(call, node, target_def, call_args)
    ordering = atomic_ordering_from_symbol_literal(call.args[-2])
    volatile = bool_from_bool_literal(call.args[-1])

    ptr = call_args.first

    inst = builder.load(ptr)
    inst.ordering = ordering
    inst.volatile = true if volatile
    set_alignment inst, node.type
    inst
  end

  def codegen_primitive_store_atomic(call, node, target_def, call_args)
    ordering = atomic_ordering_from_symbol_literal(call.args[-2])
    volatile = bool_from_bool_literal(call.args[-1])

    ptr, value = call_args

    inst = builder.store(value, ptr)
    inst.ordering = ordering
    inst.volatile = true if volatile
    set_alignment inst, node.type
    inst
  end

  def set_alignment(inst, type)
    case type
    when IntegerType, FloatType
      inst.alignment = type.bytes
    when CharType
      inst.alignment = 4
    else
      inst.alignment = @program.bits64? ? 8 : 4
    end
  end

  def atomic_ordering_from_symbol_literal(node)
    unless node.is_a?(SymbolLiteral)
      node.raise "BUG: expected symbol literal"
    end

    ordering = LLVM::AtomicOrdering.parse?(node.value)
    unless ordering
      node.raise "unknown atomic ordering: #{node.value}"
    end

    ordering
  end

  def atomicrwm_bin_op_from_symbol_literal(node)
    unless node.is_a?(SymbolLiteral)
      node.raise "BUG: expected symbol literal"
    end

    op = LLVM::AtomicRMWBinOp.parse?(node.value)
    unless op
      node.raise "unknown atomic rwm bin op: #{node.value}"
    end

    op
  end

  def bool_from_bool_literal(node)
    unless node.is_a?(BoolLiteral)
      node.raise "BUG: expected bool literal"
    end

    node.value
  end
end

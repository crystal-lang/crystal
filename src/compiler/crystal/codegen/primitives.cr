require "./codegen"

class Crystal::CodeGenVisitor
  # Can only happen in a Const or as an argument cast.
  def visit(node : Primitive)
    @last = case node.name
            when :argc
              @argc
            when :argv
              @argv
            else
              raise "Bug: unhandled primitive in codegen visit: #{node.name}"
            end
  end

  def codegen_primitive(node, target_def, call_args)
    @last = case node.name
            when :binary
              codegen_primitive_binary node, target_def, call_args
            when :cast
              codegen_primitive_cast node, target_def, call_args
            when :allocate
              codegen_primitive_allocate node, target_def, call_args
            when :pointer_malloc
              codegen_primitive_pointer_malloc node, target_def, call_args
            when :pointer_set
              codegen_primitive_pointer_set node, target_def, call_args
            when :pointer_get
              codegen_primitive_pointer_get node, target_def, call_args
            when :pointer_address
              codegen_primitive_pointer_address node, target_def, call_args
            when :pointer_new
              codegen_primitive_pointer_new node, target_def, call_args
            when :pointer_realloc
              codegen_primitive_pointer_realloc node, target_def, call_args
            when :pointer_add
              codegen_primitive_pointer_add node, target_def, call_args
            when :pointer_diff
              codegen_primitive_pointer_diff node, target_def, call_args
            when :struct_new
              codegen_primitive_struct_new node, target_def, call_args
            when :struct_set
              codegen_primitive_struct_set node, target_def, call_args
            when :struct_get
              codegen_primitive_struct_get node, target_def, call_args
            when :union_new
              codegen_primitive_union_new node, target_def, call_args
            when :union_set
              codegen_primitive_union_set node, target_def, call_args
            when :union_get
              codegen_primitive_union_get node, target_def, call_args
            when :external_var_set
              codegen_primitive_external_var_set node, target_def, call_args
            when :external_var_get
              codegen_primitive_external_var_get node, target_def, call_args
            when :object_id
              codegen_primitive_object_id node, target_def, call_args
            when :object_crystal_type_id
              codegen_primitive_object_crystal_type_id node, target_def, call_args
            when :symbol_hash
              codegen_primitive_symbol_hash node, target_def, call_args
            when :symbol_to_s
              codegen_primitive_symbol_to_s node, target_def, call_args
            when :class
              codegen_primitive_class node, target_def, call_args
            when :fun_call
              codegen_primitive_fun_call node, target_def, call_args
            when :tuple_indexer_known_index
              codegen_primitive_tuple_indexer_known_index node, target_def, call_args
            when :enum_value, :enum_new
              call_args[0]
            else
              raise "Bug: unhandled primitive in codegen: #{node.name}"
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
    else           raise "Bug: trying to codegen #{t1} #{op} #{t2}"
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
    else           raise "Bug: trying to codegen #{t1} #{op} #{t2}"
    end
  end

  def codegen_binary_op(op, t1 : SymbolType, t2 : SymbolType, p1, p2)
    case op
    when "==" then return builder.icmp LLVM::IntPredicate::EQ, p1, p2
    when "!=" then return builder.icmp LLVM::IntPredicate::NE, p1, p2
    else           raise "Bug: trying to codegen #{t1} #{op} #{t2}"
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
            else                        raise "Bug: trying to codegen #{t1} #{op} #{t2}"
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
            else           raise "Bug: trying to codegen #{t1} #{op} #{t2}"
            end
    @last = trunc_float t1, @last if t1.rank < t2.rank
    @last
  end

  def codegen_binary_op(op, t1 : TypeDefType, t2, p1, p2)
    codegen_binary_op op, t1.remove_typedef, t2, p1, p2
  end

  def codegen_binary_op(op, t1, t2, p1, p2)
    raise "Bug: codegen_binary_op called with #{t1} #{op} #{t2}"
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
    codegen_cast from_type, @mod.int32, arg
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
    raise "Bug: codegen_cast called from #{from_type} to #{to_type}"
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
      @last = cast_to @last, type
    end

    @last
  end

  def codegen_primitive_pointer_malloc(node, target_def, call_args)
    type = node.type as PointerInstanceType
    llvm_type = llvm_embedded_type(type.element_type)
    last = array_malloc(llvm_type, call_args[1])
    memset last, int8(0), llvm_type.size
    last
  end

  def codegen_primitive_pointer_set(node, target_def, call_args)
    type = context.type.remove_typedef as PointerInstanceType
    value = call_args[1]
    assign call_args[0], type.element_type, node.type, value
    value
  end

  def codegen_primitive_pointer_get(node, target_def, call_args)
    type = context.type.remove_typedef as PointerInstanceType
    to_lhs call_args[0], type.element_type
  end

  def codegen_primitive_pointer_address(node, target_def, call_args)
    ptr2int call_args[0], LLVM::Int64
  end

  def codegen_primitive_pointer_new(node, target_def, call_args)
    int2ptr(call_args[1], llvm_type(node.type))
  end

  def codegen_primitive_pointer_realloc(node, target_def, call_args)
    type = context.type as PointerInstanceType

    casted_ptr = cast_to_void_pointer(call_args[0])
    size = builder.mul call_args[1], llvm_size(type.element_type)
    reallocated_ptr = realloc casted_ptr, size
    cast_to_pointer reallocated_ptr, type.element_type
  end

  def codegen_primitive_pointer_add(node, target_def, call_args)
    gep call_args[0], call_args[1]
  end

  def codegen_primitive_struct_new(node, target_def, call_args)
    allocate_aggregate node.type
  end

  def codegen_primitive_struct_set(node, target_def, call_args)
    set_aggregate_field(node, target_def, call_args) do
      type = context.type as CStructOrUnionType
      name = target_def.name[0..-2]

      struct_field_ptr(type, name, call_args[0])
    end
  end

  def codegen_primitive_struct_get(node, target_def, call_args)
    type = context.type as CStructType
    value = to_lhs struct_field_ptr(type, target_def.name, call_args[0]), node.type
    value = check_c_fun node.type, value
    value
  end

  def struct_field_ptr(type, field_name, pointer)
    index = type.index_of_var(field_name)
    aggregate_index pointer, index
  end

  def codegen_primitive_union_new(node, target_def, call_args)
    allocate_aggregate node.type
  end

  def codegen_primitive_union_set(node, target_def, call_args)
    set_aggregate_field(node, target_def, call_args) do |field_type|
      union_field_ptr(field_type, call_args[0])
    end
  end

  def codegen_primitive_union_get(node, target_def, call_args)
    value = to_lhs union_field_ptr(node.type, call_args[0]), node.type
    value = check_c_fun node.type, value
    value
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

    var_name = target_def.name[0...-1]
    scope = context.type as CStructOrUnionType
    field_type = scope.vars[var_name].type

    # Check nil to pointer
    if node.type.nil_type? && (field_type.pointer? || field_type.fun?)
      call_arg = llvm_c_type(field_type).null
    end

    if field_type.fun?
      call_arg = check_fun_is_not_closure(call_arg, field_type)
    end

    value = to_rhs call_arg, field_type
    store value, yield(field_type)

    original_call_arg
  end

  def union_field_ptr(field_type, pointer)
    ptr = aggregate_index pointer, 0
    if field_type.is_a?(FunInstanceType)
      bit_cast ptr, @llvm_typer.fun_type(field_type).pointer
    else
      cast_to_pointer ptr, field_type
    end
  end

  def codegen_primitive_external_var_set(node, target_def, call_args)
    external = target_def as External
    name = external.real_name
    var = declare_lib_var name, node.type, external.attributes

    @last = call_args[0]

    if external.type.passed_by_value?
      @last = load @last
    end

    store @last, var

    @last = check_c_fun node.type, @last

    @last
  end

  def codegen_primitive_external_var_get(node, target_def, call_args)
    external = target_def as External
    name = (target_def as External).real_name
    var = declare_lib_var name, node.type, external.attributes

    if external.type.passed_by_value?
      @last = var
    else
      @last = load var
    end

    @last = check_c_fun node.type, @last

    @last
  end

  def codegen_primitive_object_id(node, target_def, call_args)
    ptr2int call_args[0], LLVM::Int64
  end

  def codegen_primitive_object_crystal_type_id(node, target_def, call_args)
    if context.type.is_a?(MetaclassType)
      type_id(type)
    else
      type_id(call_args[0], type)
    end
  end

  def codegen_primitive_symbol_to_s(node, target_def, call_args)
    load(gep @llvm_mod.globals[SYMBOL_TABLE_NAME], int(0), call_args[0])
  end

  def codegen_primitive_symbol_hash(node, target_def, call_args)
    call_args[0]
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
    type_id = load value
    metaclass_fun_name = "~metaclass"
    func = @main_mod.functions[metaclass_fun_name]? || create_metaclass_fun(metaclass_fun_name)
    func = check_main_fun metaclass_fun_name, func
    call func, [type_id] of LLVM::Value
  end

  def create_metaclass_fun(name)
    id_to_metaclass = @llvm_id.id_to_metaclass.to_a.sort_by! &.[0]

    define_main_function(name, ([LLVM::Int32]), LLVM::Int32) do |func|
      arg = func.params.first

      current_block = insert_block

      cases = {} of LLVM::Value => LLVM::BasicBlock
      id_to_metaclass.each do |tuple|
        type_id, metaclass_id = tuple
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

  def codegen_primitive_class_with_type(type : Type, value)
    type_id(type)
  end

  def codegen_primitive_fun_call(node, target_def, call_args)
    closure_ptr = call_args[0]
    args = call_args[1..-1]

    fun_type = context.type as FunInstanceType
    0.upto(target_def.args.size - 1) do |i|
      arg = args[i]
      fun_arg_type = fun_type.fun_types[i]
      target_def_arg_type = target_def.args[i].type
      args[i] = upcast arg, fun_arg_type, target_def_arg_type
    end

    fun_ptr = builder.extract_value closure_ptr, 0
    ctx_ptr = builder.extract_value closure_ptr, 1

    ctx_is_null_block = new_block "ctx_is_null"
    ctx_is_not_null_block = new_block "ctx_is_not_null"

    ctx_is_null = equal? ctx_ptr, LLVM::VoidPointer.null
    cond ctx_is_null, ctx_is_null_block, ctx_is_not_null_block

    old_needs_value = @needs_value
    @needs_value = true

    phi_value = Phi.open(self, node, @needs_value) do |phi|
      position_at_end ctx_is_null_block
      real_fun_ptr = bit_cast fun_ptr, llvm_fun_type(context.type)
      value = codegen_call_or_invoke(node, target_def, nil, real_fun_ptr, args, true, target_def.type, false, fun_type)
      phi.add value, node.type

      position_at_end ctx_is_not_null_block
      real_fun_ptr = bit_cast fun_ptr, llvm_closure_type(context.type)
      args.insert(0, ctx_ptr)
      value = codegen_call_or_invoke(node, target_def, nil, real_fun_ptr, args, true, target_def.type, true, fun_type)
      phi.add value, node.type, true
    end

    old_needs_value = @needs_value
    phi_value
  end

  def codegen_primitive_pointer_diff(node, target_def, call_args)
    p0 = ptr2int(call_args[0], LLVM::Int64)
    p1 = ptr2int(call_args[1], LLVM::Int64)
    sub = builder.sub p0, p1
    builder.exact_sdiv sub, ptr2int(gep(call_args[0].type.null_pointer, 1), LLVM::Int64)
  end

  def codegen_primitive_tuple_indexer_known_index(node, target_def, call_args)
    type = context.type
    if type.is_a?(TupleInstanceType)
      index = (node as TupleIndexer).index
      ptr = aggregate_index call_args[0], index
      to_lhs ptr, type.tuple_types[index]
    else
      type = (type.instance_type as TupleInstanceType)
      index = (node as TupleIndexer).index
      type_id((type.tuple_types[index] as Type).metaclass)
    end
  end

  def check_c_fun(type, value)
    if type.fun?
      make_fun(type, bit_cast(value, LLVM::VoidPointer), LLVM::VoidPointer.null)
    else
      value
    end
  end
end

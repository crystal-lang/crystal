require "./compiler"

# Code to produce bytecode to interpter all the language primitives.
# It's usually the case that every primitive needs an opcode,
# and some regular crystal functions are also done as primitives
# (for example `caller`, or doing a fiber context switch.)

class Crystal::Repl::Compiler
  private def visit_primitive(node, body, wants_struct_pointer = false)
    obj = node.obj

    case body.name
    when "unchecked_convert"
      primitive_convert(node, body, checked: false)
    when "convert"
      primitive_convert(node, body, checked: true)
    when "binary"
      primitive_binary(node, body)
    when "pointer_new"
      accept_call_members(node)
      return false unless @wants_value

      pointer_new(node: node)
    when "pointer_malloc"
      discard_value(obj) if obj
      request_value(node.args.first)

      scope_type = ((obj.try &.type) || scope).instance_type

      pointer_instance_type = scope_type.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      pointer_malloc(element_size, node: node)
      pop(aligned_sizeof_type(scope_type), node: nil) unless @wants_value
    when "pointer_realloc"
      obj ? request_value(obj) : put_self(node: node)
      request_value(node.args.first)

      scope_type = (obj.try &.type) || scope

      pointer_instance_type = scope_type.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      pointer_realloc(element_size, node: node)
      pop(aligned_sizeof_type(scope_type), node: nil) unless @wants_value
    when "pointer_set"
      # Accept in reverse order so that it's easier for the interpreter
      obj = obj.not_nil!
      element_type = obj.type.as(PointerInstanceType).element_type

      arg = node.args.first
      request_value(arg)
      dup(aligned_sizeof_type(arg), node: nil) if @wants_value
      upcast arg, arg.type, element_type

      request_value(obj)

      pointer_set(inner_sizeof_type(element_type), node: node)
    when "pointer_get"
      element_type = obj.not_nil!.type.as(PointerInstanceType).element_type

      accept_call_members(node)
      return unless @wants_value

      pointer_get(inner_sizeof_type(element_type), node: node)
    when "pointer_address"
      accept_call_members(node)
      return unless @wants_value

      pointer_address(node: node)
    when "pointer_diff"
      accept_call_members(node)
      return unless @wants_value

      pointer_diff(inner_sizeof_type(obj.not_nil!.type.as(PointerInstanceType).element_type), node: node)
    when "pointer_add"
      accept_call_members(node)
      return unless @wants_value

      pointer_add(inner_sizeof_type(obj.not_nil!.type.as(PointerInstanceType).element_type), node: node)
    when "class"
      obj = obj.not_nil!
      type = obj.type

      if type.is_a?(VirtualType)
        obj.accept self
        return unless @wants_value

        # We have a pointer to a class instance on the stack:
        # read the type ID from it
        pointer_get(sizeof(Int32), node: node)
      else
        discard_value obj
        return unless @wants_value

        put_type type, node: node
      end
    when "object_crystal_type_id"
      type =
        if obj
          discard_value(obj)
          obj.type
        else
          scope
        end

      return unless @wants_value

      put_i32 type_id(type), node: node
    when "class_crystal_instance_type_id"
      type =
        if obj
          discard_value(obj)
          obj.type
        else
          scope
        end

      return unless @wants_value

      put_i32 type_id(type.instance_type), node: node
    when "allocate"
      type =
        if obj
          discard_value(obj)
          obj.type.instance_type
        else
          scope.instance_type
        end

      return unless @wants_value

      if type.struct?
        push_zeros(aligned_instance_sizeof_type(type), node: node)
      else
        allocate_class(aligned_instance_sizeof_type(type), type_id(type), node: node)
      end

      initializer_compiled_defs = @context.type_instance_var_initializers(type)
      unless initializer_compiled_defs.empty?
        # If it's a struct we need a pointer to it
        if type.struct?
          put_stack_top_pointer(aligned_sizeof_type(type), node: nil)
        end

        # We create a method that will receive "self" to initialize each instance var,
        # and call that by passing a pointer to the class/struct. So we need to dup
        # the self pointer once per initializer, and then do one call per initializer too.
        initializer_compiled_defs.size.times do
          dup sizeof(Pointer(Void)), node: nil
        end

        initializer_compiled_defs.each do |compiled_def|
          call compiled_def, node: nil
        end

        # Pop the struct pointer
        if type.struct?
          pop(sizeof(Pointer(Void)), node: nil)
        end
      end
    when "tuple_indexer_known_index"
      obj = obj.not_nil!
      obj.accept self

      return unless @wants_value

      type = obj.type
      case type
      when TupleInstanceType
        index = body.as(TupleIndexer).index
        case index
        when Int32
          element_type = type.tuple_types[index]
          offset = @context.offset_of(type, index)
          tuple_indexer_known_index(aligned_sizeof_type(type), offset, inner_sizeof_type(element_type), node: node)
        else
          node.raise "BUG: missing handling of primitive #{body.name} with range"
        end
      when NamedTupleInstanceType
        index = body.as(TupleIndexer).index
        case index
        when Int32
          entry = type.entries[index]
          offset = @context.offset_of(type, index)
          tuple_indexer_known_index(aligned_sizeof_type(type), offset, inner_sizeof_type(entry.type), node: node)
        else
          node.raise "BUG: missing handling of primitive #{body.name} with range"
        end
      else
        node.raise "BUG: missing handling of primitive #{body.name} for #{type}"
      end
    when "enum_value"
      accept_call_members(node)
    when "enum_new"
      accept_call_args(node)
    when "symbol_to_s"
      accept_call_members(node)
      return unless @wants_value

      symbol_to_s(node: node)
    when "object_id"
      accept_call_members(node)
      return unless @wants_value

      pointer_address(node: node)
    when "proc_call"
      node.args.each { |arg| request_value(arg) }

      obj ? request_value(obj) : put_self(node: node)

      proc_call(node: node)

      pop(aligned_sizeof_type(node.type), node: nil) unless @wants_value
    when "load_atomic"
      node.args.each { |arg| request_value(arg) }

      pointer_instance_type = node.args.first.type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      load_atomic(element_size, node: node)
    when "store_atomic"
      node.args.each { |arg| request_value(arg) }

      pointer_instance_type = node.args.first.type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      store_atomic(element_size, node: node)
    when "atomicrmw"
      node.args.each { |arg| request_value(arg) }

      pointer_instance_type = node.args[1].type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      atomicrmw(element_size, node: node)
    when "cmpxchg"
      node.args.each { |arg| request_value(arg) }

      pointer_instance_type = node.args[0].type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      cmpxchg(element_size, node: node)
    when "external_var_get"
      return unless @wants_value

      lib_type = node.obj.not_nil!.type.as(LibType)
      external = node.target_def.as(External)

      fn = @context.c_function(lib_type, external.real_name)

      # Put the symbol address, which is a pointer
      put_u64 fn.address, node: node

      # Read from the pointer
      pointer_get(inner_sizeof_type(node), node: node)
    when "external_var_set"
      lib_type = node.obj.not_nil!.type.as(LibType)
      external = node.target_def.as(External)

      # pointer_set needs first arg, then obj
      arg = node.args.first
      request_value(arg)
      dup(aligned_sizeof_type(arg), node: nil) if @wants_value

      fn = @context.c_function(lib_type, external.real_name)

      # Put the symbol address, which is a pointer
      put_u64 fn.address, node: node

      # Set the pointer's value
      pointer_set(inner_sizeof_type(node), node: node)
    when "struct_or_union_set"
      obj = obj.not_nil!
      arg = node.args.first

      # Check if we need an extra conversion like `to_i32!` or `to_unsafe`
      extra = body.extra
      if extra
        # It seems extra is always a Call, so this is always safe
        # TODO: consider changing Primitive#@extra to be `Call?`
        call = extra.as(Call)
        call.obj = arg
        arg = call
      end

      case obj
      when Var, InstanceVar, ClassVar
        # all good
      else
        # we'll need to accept obj, but at that pointer modifying
        # the struct will be pointless, so we just ignore setting
        # a value altogether.
        discard_value(obj)
        arg.accept self
        return
      end

      type = obj.type.as(NonGenericClassType)

      ivar_name = '@' + node.name.rchop # remove the '=' suffix
      ivar = type.lookup_instance_var(ivar_name)
      ivar_offset = ivar_offset(type, ivar_name)
      ivar_size = inner_sizeof_type(type.lookup_instance_var(ivar_name))

      # pointer_set needs first arg, then obj
      request_value(arg)
      dup(aligned_sizeof_type(arg), node: nil) if @wants_value

      upcast arg, arg.type, ivar.type

      ivar_type = ivar.type
      arg_type = arg.type
      is_proc_type = false

      # When assigning a proc to an extern struct field we need
      # to remove the closure data part.
      if ivar_type.is_a?(ProcInstanceType) && arg_type.is_a?(ProcInstanceType)
        proc_to_c_fun arg_type.ffi_call_interface, node: nil
        is_proc_type = true
      end

      # With this we get a pointer to the struct
      compile_pointerof_node(obj, obj.type)

      # Shift the pointer to the offset, if needed
      if ivar_offset > 0
        put_i64 1, node: nil
        pointer_add(ivar_offset, node: node)
      end

      if is_proc_type
        pointer_set(sizeof(Void*), node: node)
      else
        pointer_set(inner_sizeof_type(ivar.type), node: node)
      end
    when "interpreter_call_stack_unwind"
      interpreter_call_stack_unwind(node: node)
    when "interpreter_raise_without_backtrace"
      accept_call_args(node)
      interpreter_raise_without_backtrace(node: node)
    when "interpreter_current_fiber"
      interpreter_current_fiber(node: node)
    when "interpreter_spawn"
      accept_call_args(node)
      interpreter_spawn(node: node)
    when "interpreter_fiber_swapcontext"
      accept_call_args(node)
      interpreter_fiber_swapcontext(node: node)
    when "interpreter_intrinsics_memcpy"
      accept_call_args(node)
      interpreter_intrinsics_memcpy(node: node)
    when "interpreter_intrinsics_memmove"
      accept_call_args(node)
      interpreter_intrinsics_memmove(node: node)
    when "interpreter_intrinsics_memset"
      accept_call_args(node)
      interpreter_intrinsics_memset(node: node)
    when "interpreter_intrinsics_debugtrap"
      interpreter_intrinsics_debugtrap(node: node)
    when "interpreter_intrinsics_pause"
      # TODO: given that this is interpreted, maybe `pause` can be nop instead of a real pause?
      {% if flag?(:i386) || flag?(:x86_64) %}
        interpreter_intrinsics_pause(node: node)
      {% end %}
    when "interpreter_intrinsics_bswap32"
      interpreter_intrinsics_bswap32(node: node)
    when "interpreter_intrinsics_bswap16"
      interpreter_intrinsics_bswap16(node: node)
    when "interpreter_intrinsics_read_cycle_counter"
      interpreter_intrinsics_read_cycle_counter(node: node)
    when "interpreter_intrinsics_popcount8"
      accept_call_args(node)
      interpreter_intrinsics_popcount8(node: node)
    when "interpreter_intrinsics_popcount16"
      accept_call_args(node)
      interpreter_intrinsics_popcount16(node: node)
    when "interpreter_intrinsics_popcount32"
      accept_call_args(node)
      interpreter_intrinsics_popcount32(node: node)
    when "interpreter_intrinsics_popcount64"
      accept_call_args(node)
      interpreter_intrinsics_popcount64(node: node)
    when "interpreter_intrinsics_countleading8"
      accept_call_args(node)
      interpreter_intrinsics_countleading8(node: node)
    when "interpreter_intrinsics_countleading16"
      accept_call_args(node)
      interpreter_intrinsics_countleading16(node: node)
    when "interpreter_intrinsics_countleading32"
      accept_call_args(node)
      interpreter_intrinsics_countleading32(node: node)
    when "interpreter_intrinsics_countleading64"
      accept_call_args(node)
      interpreter_intrinsics_countleading64(node: node)
    when "interpreter_intrinsics_counttrailing8"
      accept_call_args(node)
      interpreter_intrinsics_counttrailing8(node: node)
    when "interpreter_intrinsics_counttrailing16"
      accept_call_args(node)
      interpreter_intrinsics_counttrailing16(node: node)
    when "interpreter_intrinsics_counttrailing32"
      accept_call_args(node)
      interpreter_intrinsics_counttrailing32(node: node)
    when "interpreter_intrinsics_counttrailing64"
      accept_call_args(node)
      interpreter_intrinsics_counttrailing64(node: node)
    when "interpreter_libm_ceil_f32"
      accept_call_args(node)
      libm_ceil_f32 node: node
    when "interpreter_libm_ceil_f64"
      accept_call_args(node)
      libm_ceil_f64 node: node
    when "interpreter_libm_cos_f32"
      accept_call_args(node)
      libm_cos_f32 node: node
    when "interpreter_libm_cos_f64"
      accept_call_args(node)
      libm_cos_f64 node: node
    when "interpreter_libm_exp_f32"
      accept_call_args(node)
      libm_exp_f32 node: node
    when "interpreter_libm_exp_f64"
      accept_call_args(node)
      libm_exp_f64 node: node
    when "interpreter_libm_exp2_f32"
      accept_call_args(node)
      libm_exp2_f32 node: node
    when "interpreter_libm_exp2_f64"
      accept_call_args(node)
      libm_exp2_f64 node: node
    when "interpreter_libm_floor_f32"
      accept_call_args(node)
      libm_floor_f32 node: node
    when "interpreter_libm_floor_f64"
      accept_call_args(node)
      libm_floor_f64 node: node
    when "interpreter_libm_log_f32"
      accept_call_args(node)
      libm_log_f32 node: node
    when "interpreter_libm_log_f64"
      accept_call_args(node)
      libm_log_f64 node: node
    when "interpreter_libm_log2_f32"
      accept_call_args(node)
      libm_log2_f32 node: node
    when "interpreter_libm_log2_f64"
      accept_call_args(node)
      libm_log2_f64 node: node
    when "interpreter_libm_log10_f32"
      accept_call_args(node)
      libm_log10_f32 node: node
    when "interpreter_libm_log10_f64"
      accept_call_args(node)
      libm_log10_f64 node: node
    when "interpreter_libm_round_f32"
      accept_call_args(node)
      libm_round_f32 node: node
    when "interpreter_libm_round_f64"
      accept_call_args(node)
      libm_round_f64 node: node
    when "interpreter_libm_rint_f32"
      accept_call_args(node)
      libm_rint_f32 node: node
    when "interpreter_libm_rint_f64"
      accept_call_args(node)
      libm_rint_f64 node: node
    when "interpreter_libm_sin_f32"
      accept_call_args(node)
      libm_sin_f32 node: node
    when "interpreter_libm_sin_f64"
      accept_call_args(node)
      libm_sin_f64 node: node
    when "interpreter_libm_sqrt_f32"
      accept_call_args(node)
      libm_sqrt_f32 node: node
    when "interpreter_libm_sqrt_f64"
      accept_call_args(node)
      libm_sqrt_f64 node: node
    when "interpreter_libm_trunc_f32"
      accept_call_args(node)
      libm_trunc_f32 node: node
    when "interpreter_libm_trunc_f64"
      accept_call_args(node)
      libm_trunc_f64 node: node
    when "interpreter_libm_powi_f32"
      accept_call_args(node)
      libm_powi_f32 node: node
    when "interpreter_libm_powi_f64"
      accept_call_args(node)
      libm_powi_f64 node: node
    when "interpreter_libm_min_f32"
      accept_call_args(node)
      libm_min_f32 node: node
    when "interpreter_libm_min_f64"
      accept_call_args(node)
      libm_min_f64 node: node
    when "interpreter_libm_max_f32"
      accept_call_args(node)
      libm_max_f32 node: node
    when "interpreter_libm_max_f64"
      accept_call_args(node)
      libm_max_f64 node: node
    when "interpreter_libm_pow_f32"
      accept_call_args(node)
      libm_pow_f32 node: node
    when "interpreter_libm_pow_f64"
      accept_call_args(node)
      libm_pow_f64 node: node
    when "interpreter_libm_copysign_f32"
      accept_call_args(node)
      libm_copysign_f32 node: node
    when "interpreter_libm_copysign_f64"
      accept_call_args(node)
      libm_copysign_f64 node: node
    else
      node.raise "BUG: missing handling of primitive #{body.name}"
    end
  end

  private def accept_call_args(node : Call)
    node.args.each { |arg| request_value(arg) }
  end

  private def primitive_convert(node : ASTNode, body : Primitive, checked : Bool)
    obj = node.obj

    return false if !obj && !@wants_value

    obj_type =
      if obj
        obj.accept self
        obj.type
      else
        put_self(node: node)
        scope
      end

    return false unless @wants_value

    target_type = body.type

    primitive_convert(node, obj_type, target_type, checked: checked)
  end

  private def primitive_convert(node : ASTNode, from_type : IntegerType | FloatType, to_type : IntegerType | FloatType, checked : Bool)
    from_kind = integer_or_float_kind(from_type)
    to_kind = integer_or_float_kind(to_type)

    unless from_kind && to_kind
      node.raise "BUG: missing handling of unchecked_convert for #{from_type} (#{node.name})"
    end

    primitive_convert(node, from_kind, to_kind, checked: checked)
  end

  private def primitive_convert(node : ASTNode, from_type : CharType, to_type : IntegerType, checked : Bool)
    # This is Char#ord
    nop
  end

  private def primitive_convert(node : ASTNode, from_type : IntegerType, to_type : CharType, checked : Bool)
    primitive_convert(node, from_type, @context.program.int32, checked: checked)
  end

  private def primitive_convert(node : ASTNode, from_type : SymbolType, to_type : IntegerType, checked : Bool)
    # This is Symbol#to_i, but a symbol is already represented as an Int32
    nop
  end

  private def primitive_convert(node : ASTNode, from_type : Type, to_type : Type, checked : Bool)
    node.raise "BUG: missing handling of convert from #{from_type} to #{to_type}"
  end

  private def primitive_convert(node : ASTNode, from_kind : Symbol, to_kind : Symbol, checked : Bool)
    # Most of these are nop because we align the stack to 64 bits,
    # so numbers are already converted to 64 bits
    case {from_kind, to_kind}
    when {:i8, :i8}   then nop
    when {:i8, :i16}  then sign_extend(7, node: node)
    when {:i8, :i32}  then sign_extend(7, node: node)
    when {:i8, :i64}  then sign_extend(7, node: node)
    when {:i8, :u8}   then checked ? (sign_extend(7, node: node); i64_to_u8(node: node)) : nop
    when {:i8, :u16}  then sign_extend(7, node: node); checked ? i64_to_u16(node: node) : nop
    when {:i8, :u32}  then sign_extend(7, node: node); checked ? i64_to_u32(node: node) : nop
    when {:i8, :u64}  then sign_extend(7, node: node); checked ? i64_to_u64(node: node) : nop
    when {:i8, :f32}  then sign_extend(7, node: node); i64_to_f32(node: node)
    when {:i8, :f64}  then sign_extend(7, node: node); i64_to_f64(node: node)
    when {:u8, :i8}   then zero_extend(7, node: node); checked ? u64_to_i8(node: node) : nop
    when {:u8, :i16}  then zero_extend(7, node: node)
    when {:u8, :i32}  then zero_extend(7, node: node)
    when {:u8, :i64}  then zero_extend(7, node: node)
    when {:u8, :u8}   then nop
    when {:u8, :u16}  then zero_extend(7, node: node)
    when {:u8, :u32}  then zero_extend(7, node: node)
    when {:u8, :u64}  then zero_extend(7, node: node)
    when {:u8, :f32}  then zero_extend(7, node: node); u64_to_f32(node: node)
    when {:u8, :f64}  then zero_extend(7, node: node); u64_to_f64(node: node)
    when {:i16, :i8}  then checked ? (sign_extend(6, node: node); i64_to_i8(node: node)) : nop
    when {:i16, :i16} then nop
    when {:i16, :i32} then sign_extend(6, node: node)
    when {:i16, :i64} then sign_extend(6, node: node)
    when {:i16, :u8}  then checked ? (sign_extend(6, node: node); i64_to_u8(node: node)) : nop
    when {:i16, :u16} then checked ? (sign_extend(6, node: node); i64_to_u16(node: node)) : nop
    when {:i16, :u32} then sign_extend(6, node: node); checked ? i64_to_u32(node: node) : nop
    when {:i16, :u64} then sign_extend(6, node: node); checked ? i64_to_u64(node: node) : nop
    when {:i16, :f32} then sign_extend(6, node: node); i64_to_f32(node: node)
    when {:i16, :f64} then sign_extend(6, node: node); i64_to_f64(node: node)
    when {:u16, :i8}  then checked ? (zero_extend(6, node: node); u64_to_i8(node: node)) : nop
    when {:u16, :i16} then checked ? (zero_extend(6, node: node); u64_to_i16(node: node)) : nop
    when {:u16, :i32} then zero_extend(6, node: node)
    when {:u16, :i64} then zero_extend(6, node: node)
    when {:u16, :u8}  then nop
    when {:u16, :u16} then nop
    when {:u16, :u32} then zero_extend(6, node: node)
    when {:u16, :u64} then zero_extend(6, node: node)
    when {:u16, :f32} then zero_extend(6, node: node); u64_to_f32(node: node)
    when {:u16, :f64} then zero_extend(6, node: node); u64_to_f64(node: node)
    when {:i32, :i8}  then checked ? (sign_extend(4, node: node); i64_to_i8(node: node)) : nop
    when {:i32, :i16} then checked ? (sign_extend(4, node: node); i64_to_i16(node: node)) : nop
    when {:i32, :i32} then nop
    when {:i32, :i64} then sign_extend(4, node: node)
    when {:i32, :u8}  then checked ? (sign_extend(4, node: node); i64_to_u8(node: node)) : nop
    when {:i32, :u16} then checked ? (sign_extend(4, node: node); i64_to_u16(node: node)) : nop
    when {:i32, :u32} then checked ? (sign_extend(4, node: node); i64_to_u32(node: node)) : nop
    when {:i32, :u64} then checked ? (sign_extend(4, node: node); i64_to_u64(node: node)) : sign_extend(4, node: node)
    when {:i32, :f32} then sign_extend(4, node: node); i64_to_f32(node: node)
    when {:i32, :f64} then sign_extend(4, node: node); i64_to_f64(node: node)
    when {:u32, :i8}  then checked ? (zero_extend(4, node: node); u64_to_i8(node: node)) : nop
    when {:u32, :i16} then checked ? (zero_extend(4, node: node); u64_to_i16(node: node)) : nop
    when {:u32, :i32} then checked ? (zero_extend(4, node: node); u64_to_i32(node: node)) : nop
    when {:u32, :i64} then zero_extend(4, node: node)
    when {:u32, :u8}  then checked ? (zero_extend(4, node: node); u64_to_u8(node: node)) : nop
    when {:u32, :u16} then checked ? (zero_extend(4, node: node); u64_to_u16(node: node)) : nop
    when {:u32, :u32} then nop
    when {:u32, :u64} then zero_extend(4, node: node)
    when {:u32, :f32} then zero_extend(4, node: node); u64_to_f32(node: node)
    when {:u32, :f64} then zero_extend(4, node: node); u64_to_f64(node: node)
    when {:i64, :i8}  then checked ? i64_to_i8(node: node) : nop
    when {:i64, :i16} then checked ? i64_to_i16(node: node) : nop
    when {:i64, :i32} then checked ? i64_to_i32(node: node) : nop
    when {:i64, :i64} then nop
    when {:i64, :u8}  then checked ? i64_to_u8(node: node) : nop
    when {:i64, :u16} then checked ? i64_to_u16(node: node) : nop
    when {:i64, :u32} then checked ? i64_to_u32(node: node) : nop
    when {:i64, :u64} then checked ? i64_to_u64(node: node) : nop
    when {:i64, :f32} then i64_to_f32(node: node)
    when {:i64, :f64} then i64_to_f64(node: node)
    when {:u64, :i8}  then checked ? u64_to_i8(node: node) : nop
    when {:u64, :i16} then checked ? u64_to_i16(node: node) : nop
    when {:u64, :i32} then checked ? u64_to_i32(node: node) : nop
    when {:u64, :i64} then checked ? u64_to_i64(node: node) : nop
    when {:u64, :u8}  then checked ? u64_to_u8(node: node) : nop
    when {:u64, :u16} then checked ? u64_to_u16(node: node) : nop
    when {:u64, :u32} then checked ? u64_to_u32(node: node) : nop
    when {:u64, :u64} then nop
    when {:u64, :f32} then u64_to_f32(node: node)
    when {:u64, :f64} then u64_to_f64(node: node)
    when {:f32, :i8}  then f32_to_f64(node: node); checked ? f64_to_i8(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :i16} then f32_to_f64(node: node); checked ? f64_to_i16(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :i32} then f32_to_f64(node: node); checked ? f64_to_i32(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :i64} then f32_to_f64(node: node); checked ? f64_to_i64(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :u8}  then f32_to_f64(node: node); checked ? f64_to_u8(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :u16} then f32_to_f64(node: node); checked ? f64_to_u16(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :u32} then f32_to_f64(node: node); checked ? f64_to_u32(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :u64} then f32_to_f64(node: node); checked ? f64_to_u64(node: node) : f64_to_i64_bang(node: node)
    when {:f32, :f32} then nop
    when {:f32, :f64} then f32_to_f64(node: node)
    when {:f64, :i8}  then checked ? f64_to_i8(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :i16} then checked ? f64_to_i16(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :i32} then checked ? f64_to_i32(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :i64} then checked ? f64_to_i64(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :u8}  then checked ? f64_to_u8(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :u16} then checked ? f64_to_u16(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :u32} then checked ? f64_to_u32(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :u64} then checked ? f64_to_u64(node: node) : f64_to_i64_bang(node: node)
    when {:f64, :f32} then checked ? f64_to_f32(node: node) : f64_to_f32_bang(node: node)
    when {:f64, :f64} then nop
    else                   node.raise "BUG: missing handling of unchecked_convert for #{from_kind} - #{to_kind}"
    end
  end

  private def primitive_binary(node, body)
    unless @wants_value
      node.obj.try &.accept self
      node.args.each &.accept self
      return
    end

    case node.name
    when "+", "&+", "-", "&-", "*", "&*", "^", "|", "&", "unsafe_shl", "unsafe_shr", "unsafe_div", "unsafe_mod"
      primitive_binary_op_math(node, body, node.name)
    when "<", "<=", ">", ">=", "==", "!="
      primitive_binary_op_cmp(node, body, node.name)
    when "/", "fdiv"
      primitive_binary_float_div(node, body)
    else
      node.raise "BUG: missing handling of binary op #{node.name}"
    end
  end

  private def primitive_binary_op_math(node : ASTNode, body : Primitive, op : String)
    obj = node.obj
    arg = node.args.first

    obj_type = obj.try(&.type) || scope
    arg_type = arg.type

    primitive_binary_op_math(obj_type, arg_type, obj, arg, node, op)
  end

  private def primitive_binary_op_math(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    kind = extend_int(left_type, right_type, left_node, right_node, node)
    if kind
      # Go on
      return false unless @wants_value

      primitive_binary_op_math(node, kind, op)
    elsif left_type.rank > right_type.rank
      # It's UInt64 op X where X is a signed integer
      left_node ? left_node.accept(self) : put_self(node: node)
      right_node.accept self

      # TODO: do we need to check for overflow here?
      primitive_convert(node, right_type.kind, :i64, checked: false)

      case node.name
      when "+"          then add_u64_i64(node: node)
      when "&+"         then add_wrap_i64(node: node)
      when "-"          then sub_u64_i64(node: node)
      when "&-"         then sub_wrap_i64(node: node)
      when "*"          then mul_u64_i64(node: node)
      when "&*"         then mul_wrap_i64(node: node)
      when "^"          then xor_i64(node: node)
      when "|"          then or_i64(node: node)
      when "&"          then and_i64(node: node)
      when "unsafe_shl" then unsafe_shl_i64(node: node)
      when "unsafe_shr" then unsafe_shr_u64_i64(node: node)
      when "unsafe_div" then unsafe_div_u64_i64(node: node)
      when "unsafe_mod" then unsafe_mod_u64_i64(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end

      kind = :u64
    else
      # It's X op UInt64 where X is a signed integer
      left_node ? left_node.accept(self) : put_self(node: node)

      # TODO: do we need to check for overflow here?
      primitive_convert(node, left_type.kind, :i64, checked: false)
      right_node.accept self

      case node.name
      when "+"          then add_i64_u64(node: node)
      when "&+"         then add_wrap_i64(node: node)
      when "-"          then sub_i64_u64(node: node)
      when "&-"         then sub_wrap_i64(node: node)
      when "*"          then mul_i64_u64(node: node)
      when "&*"         then mul_wrap_i64(node: node)
      when "^"          then xor_i64(node: node)
      when "|"          then or_i64(node: node)
      when "&"          then and_i64(node: node)
      when "unsafe_shl" then unsafe_shl_i64(node: node)
      when "unsafe_shr" then unsafe_shr_i64_u64(node: node)
      when "unsafe_div" then unsafe_div_i64_u64(node: node)
      when "unsafe_mod" then unsafe_mod_i64_u64(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
      end

      kind = :i64
    end

    if kind != left_type.kind
      checked = node.name.in?("+", "-", "*")
      primitive_convert(node, kind, left_type.kind, checked: checked)
    end
  end

  private def primitive_binary_op_math(left_type : IntegerType, right_type : FloatType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    left_node ? left_node.accept(self) : put_self(node: node)
    primitive_convert node, left_type.kind, right_type.kind, checked: false
    right_node.accept self

    primitive_binary_op_math(node, right_type.kind, op)
  end

  private def primitive_binary_op_math(left_type : FloatType, right_type : IntegerType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    left_node ? left_node.accept(self) : put_self(node: node)
    right_node.accept self
    primitive_convert right_node, right_type.kind, left_type.kind, checked: false

    primitive_binary_op_math(node, left_type.kind, op)
  end

  private def primitive_binary_op_math(left_type : FloatType, right_type : FloatType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    if left_type == right_type
      left_node ? left_node.accept(self) : put_self(node: node)
      right_node.accept self
      kind = left_type.kind
    elsif left_type.rank < right_type.rank
      # TODO: not tested
      left_node ? left_node.accept(self) : put_self(node: node)
      primitive_convert node, left_type.kind, right_type.kind, checked: false
      right_node.accept self
      kind = right_type.kind
    else
      # TODO: not tested
      left_node ? left_node.accept(self) : put_self(node: node)
      right_node.accept self
      primitive_convert right_node, right_type.kind, left_type.kind, checked: false
      kind = left_type.kind
    end

    primitive_binary_op_math(node, kind, op)

    if kind != left_type.kind
      primitive_convert(node, kind, left_type.kind, checked: false)
    end
  end

  private def primitive_binary_op_math(node : ASTNode, kind : Symbol, op : String)
    case kind
    when :i32
      case op
      when "+"          then add_i32(node: node)
      when "&+"         then add_wrap_i32(node: node)
      when "-"          then sub_i32(node: node)
      when "&-"         then sub_wrap_i32(node: node)
      when "*"          then mul_i32(node: node)
      when "&*"         then mul_wrap_i32(node: node)
      when "^"          then xor_i32(node: node)
      when "|"          then or_i32(node: node)
      when "&"          then and_i32(node: node)
      when "unsafe_shl" then unsafe_shl_i32(node: node)
      when "unsafe_shr" then unsafe_shr_i32(node: node)
      when "unsafe_div" then unsafe_div_i32(node: node)
      when "unsafe_mod" then unsafe_mod_i32(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when :u32
      case op
      when "+"          then add_u32(node: node)
      when "&+"         then add_wrap_i32(node: node)
      when "-"          then sub_u32(node: node)
      when "&-"         then sub_wrap_i32(node: node)
      when "*"          then mul_u32(node: node)
      when "&*"         then mul_wrap_i32(node: node)
      when "^"          then xor_i32(node: node)
      when "|"          then or_i32(node: node)
      when "&"          then and_i32(node: node)
      when "unsafe_shl" then unsafe_shl_i32(node: node)
      when "unsafe_shr" then unsafe_shr_u32(node: node)
      when "unsafe_div" then unsafe_div_u32(node: node)
      when "unsafe_mod" then unsafe_mod_u32(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when :i64
      case op
      when "+"          then add_i64(node: node)
      when "&+"         then add_wrap_i64(node: node)
      when "-"          then sub_i64(node: node)
      when "&-"         then sub_wrap_i64(node: node)
      when "*"          then mul_i64(node: node)
      when "&*"         then mul_wrap_i64(node: node)
      when "^"          then xor_i64(node: node)
      when "|"          then or_i64(node: node)
      when "&"          then and_i64(node: node)
      when "unsafe_shl" then unsafe_shl_i64(node: node)
      when "unsafe_shr" then unsafe_shr_i64(node: node)
      when "unsafe_div" then unsafe_div_i64(node: node)
      when "unsafe_mod" then unsafe_mod_i64(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when :u64
      case op
      when "+"          then add_u64(node: node)
      when "&+"         then add_wrap_i64(node: node)
      when "-"          then sub_u64(node: node)
      when "&-"         then sub_wrap_i64(node: node)
      when "*"          then mul_u64(node: node)
      when "&*"         then mul_wrap_i64(node: node)
      when "^"          then xor_i64(node: node)
      when "|"          then or_i64(node: node)
      when "&"          then and_i64(node: node)
      when "unsafe_shl" then unsafe_shl_i64(node: node)
      when "unsafe_shr" then unsafe_shr_u64(node: node)
      when "unsafe_div" then unsafe_div_u64(node: node)
      when "unsafe_mod" then unsafe_mod_u64(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when :f32
      # TODO: not tested
      case op
      when "+" then add_f32(node: node)
      when "-" then sub_f32(node: node)
      when "*" then mul_f32(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when :f64
      case op
      when "+" then add_f64(node: node)
      when "-" then sub_f64(node: node)
      when "*" then mul_f64(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    else
      node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
    end
  end

  private def primitive_binary_op_math(left_type : Type, right_type : Type, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    node.raise "BUG: primitive_binary_op_math called with #{left_type} #{op} #{right_type}"
  end

  private def primitive_binary_op_cmp(node : ASTNode, body : Primitive, op : String)
    obj = node.obj.not_nil!
    arg = node.args.first

    obj_type = obj.type
    arg_type = arg.type

    primitive_binary_op_cmp(obj_type, arg_type, obj, arg, node, op)
  end

  private def primitive_binary_op_cmp(left_type : BoolType, right_type : BoolType, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    left_node.accept self
    right_node.accept self

    cmp_i32(node: node)
    primitive_binary_op_cmp_op(node, op)
  end

  private def primitive_binary_op_cmp(left_type : CharType, right_type : CharType, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    left_node.accept self
    right_node.accept self

    cmp_i32(node: node)
    primitive_binary_op_cmp_op(node, op)
  end

  private def primitive_binary_op_cmp(left_type : SymbolType, right_type : SymbolType, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    left_node.accept self
    right_node.accept self

    cmp_i32(node: node)
    primitive_binary_op_cmp_op(node, op)
  end

  private def primitive_binary_op_cmp(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    kind = extend_int(left_type, right_type, left_node, right_node, node)
    if kind
      case kind
      when :i32 then cmp_i32(node: node)
      when :u32 then cmp_u32(node: node)
      when :i64 then cmp_i64(node: node)
      when :u64 then cmp_u64(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} for #{kind}"
      end
    elsif left_type.rank > right_type.rank
      # It's UInt64 == X where X is a signed integer.

      # We first extend right to left
      left_node.accept self
      right_node.accept self

      # TODO: do we need to check for overflow here?
      primitive_convert right_node, right_type.kind, :i64, checked: false

      cmp_u64_i64(node: node)
    else
      # It's X < UInt64 where X is a signed integer
      left_node.accept self

      # TODO: do we need to check for overflow here?
      primitive_convert left_node, left_type.kind, :i64, checked: false

      right_node.accept self

      cmp_i64_u64(node: node)
    end

    primitive_binary_op_cmp_op(node, op)
  end

  private def primitive_binary_op_cmp(left_type : FloatType, right_type : IntegerType, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    left_node.accept self
    right_node.accept self
    primitive_convert right_node, right_type.kind, left_type.kind, checked: false

    primitive_binary_op_cmp_float(node, left_type.kind, op)
  end

  private def primitive_binary_op_cmp(left_type : IntegerType, right_type : FloatType, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    left_node.accept self
    primitive_convert(left_node, left_type.kind, right_type.kind, checked: false)
    right_node.accept self

    primitive_binary_op_cmp_float(node, right_type.kind, op)
  end

  private def primitive_binary_op_cmp(left_type : FloatType, right_type : FloatType, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    if left_type == right_type
      left_node.accept self
      right_node.accept self

      kind = left_type.kind
    elsif left_type.rank < right_type.rank
      left_node.accept self
      primitive_convert(left_node, left_type.kind, right_type.kind, checked: false)
      right_node.accept self

      kind = :f64
    else
      left_node.accept self
      right_node.accept self
      primitive_convert(right_node, right_type.kind, left_type.kind, checked: false)

      kind = :f64
    end

    primitive_binary_op_cmp_float(node, kind, op)
  end

  private def primitive_binary_op_cmp(left_type : Type, right_type : Type, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    left_node.raise "BUG: primitive_binary_op_cmp called with #{left_type} #{op} #{right_type}"
  end

  private def primitive_binary_op_cmp_float(node : ASTNode, kind : Symbol, op : String)
    case kind
    when :f32 then cmp_f32(node: node)
    when :f64 then cmp_f64(node: node)
    else
      node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
    end

    primitive_binary_op_cmp_op(node, op)
  end

  private def primitive_binary_op_cmp_op(node : ASTNode, op : String)
    case op
    when "==" then cmp_eq(node: node)
    when "!=" then cmp_neq(node: node)
    when "<"  then cmp_lt(node: node)
    when "<=" then cmp_le(node: node)
    when ">"  then cmp_gt(node: node)
    when ">=" then cmp_ge(node: node)
    else
      node.raise "BUG: missing handling of binary #{op}"
    end
  end

  private def extend_int(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode)
    # We don't do operations "below" Int32, we always cast the values
    # to at least Int32. This might be slightly slower, but it allows
    # us to need less opcodes in the bytecode.
    if left_type.rank <= 5 && right_type.rank <= 5
      # If both fit in an Int32
      # Convert them to Int32 first, then do the comparison
      left_node ? left_node.accept(self) : put_self(node: node)
      primitive_convert(left_node || right_node, left_type.kind, :i32, checked: false) if left_type.rank < 5

      right_node.accept self
      primitive_convert(right_node, right_type.kind, :i32, checked: false) if right_type.rank < 5

      :i32
    elsif left_type.signed? == right_type.signed?
      if left_type.rank == right_type.rank
        left_node ? left_node.accept(self) : put_self(node: node)
        right_node.accept self
        left_type.kind
      elsif left_type.rank < right_type.rank
        left_node ? left_node.accept(self) : put_self(node: node)
        primitive_convert(left_node || right_node, left_type.kind, right_type.kind, checked: false)
        right_node.accept self
        right_type.kind
      else
        left_node ? left_node.accept(self) : put_self(node: node)
        right_node.accept self
        primitive_convert(right_node, right_type.kind, left_type.kind, checked: false)
        left_type.kind
      end
    elsif left_type.rank <= 7 && right_type.rank <= 7
      # If both fit in an Int64
      # Convert them to Int64 first, then do the comparison
      left_node ? left_node.accept(self) : put_self(node: node)
      primitive_convert(left_node || right_node, left_type.kind, :i64, checked: false) if left_type.rank < 7

      right_node.accept self
      primitive_convert(right_node, right_type.kind, :i64, checked: false) if right_type.rank < 7

      :i64
    else
      nil
    end
  end

  private def primitive_binary_float_div(node : ASTNode, body)
    # TODO: don't assume Float64 op Float64
    obj = node.obj.not_nil!
    arg = node.args.first

    obj_type = obj.type
    arg_type = arg.type

    obj_kind = integer_or_float_kind(obj_type).not_nil!
    arg_kind = integer_or_float_kind(arg_type).not_nil!

    obj.accept self
    if (obj_type.is_a?(IntegerType) && arg_type.is_a?(FloatType)) ||
       (obj_type.is_a?(FloatType) && arg_type.is_a?(FloatType) && obj_type.rank < arg_type.rank)
      primitive_convert(obj, obj_kind, arg_kind, checked: false)
      obj_kind = arg_kind
    end

    arg.accept self
    if (obj_type.is_a?(FloatType) && arg_type.is_a?(IntegerType)) ||
       (obj_type.is_a?(FloatType) && arg_type.is_a?(FloatType) && obj_type.rank > arg_type.rank)
      primitive_convert(arg, arg_kind, obj_kind, checked: false)
      arg_kind = obj_kind
    end

    case {obj_kind, arg_kind}
    when {:f32, :f32}
      div_f32(node: node)
    when {:f64, :f64}
      div_f64(node: node)
    else
      node.raise "BUG: missing handling of binary float div with types #{obj_type} and #{arg_type}"
    end

    if obj_type.is_a?(FloatType) && arg_type.is_a?(FloatType) && obj_type.rank < arg_type.rank
      primitive_convert(node, :f64, :f32, checked: false)
    end
  end

  private def integer_or_float_kind(type)
    case type
    when IntegerType
      type.kind
    when FloatType
      type.kind
    else
      nil
    end
  end

  private def collect_instance_vars_initializers(type : ClassType | GenericClassInstanceType, collected)
    if superclass = type.superclass
      collect_instance_vars_initializers superclass, collected
    end

    collect_instance_vars_initializers_non_recursive type, collected
  end

  private def collect_instance_vars_initializers(type : Type, collected)
    # Nothing to do
  end

  private def collect_instance_vars_initializers_non_recursive(type : Type, collected)
    initializers = type.instance_vars_initializers
    collected.concat initializers if initializers
  end
end

require "./compiler"

# Code to produce bytecode to interpret all the language primitives.
# It's usually the case that every primitive needs an opcode,
# and some regular crystal functions are also done as primitives
# (for example `caller`, or doing a fiber context switch.)

class Crystal::Repl::Compiler
  private def visit_primitive(node, body, target_def)
    owner = node.super? ? node.scope : node.target_def.owner
    obj = node.obj

    case body.name
    when "unchecked_convert"
      primitive_convert(node, body, owner, checked: false)
    when "convert"
      primitive_convert(node, body, owner, checked: true)
    when "binary"
      primitive_binary(node, body, owner)
    when "pointer_new"
      accept_call_members(node)
      return false unless @wants_value

      pointer_new(node: node)
    when "pointer_malloc"
      discard_value(obj) if obj
      request_value(node.args.first)

      pointer_instance_type = owner.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      pointer_malloc(element_size, node: node)
      pop(aligned_sizeof_type(pointer_instance_type), node: nil) unless @wants_value
    when "pointer_realloc"
      obj ? request_value(obj) : put_self(node: node)
      request_value(node.args.first)

      pointer_instance_type = owner.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      pointer_realloc(element_size, node: node)
      pop(aligned_sizeof_type(pointer_instance_type), node: nil) unless @wants_value
    when "pointer_set"
      # Accept in reverse order so that it's easier for the interpreter
      obj = obj.not_nil!

      pointer_instance_type = owner.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type

      arg = node.args.first
      request_value(arg)
      dup(aligned_sizeof_type(arg), node: nil) if @wants_value
      upcast arg, arg.type, element_type

      request_value(obj)

      pointer_set(inner_sizeof_type(element_type), node: node)
    when "pointer_get"
      pointer_instance_type = owner.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type

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

      pointer_instance_type = owner.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type

      pointer_diff(inner_sizeof_type(element_type), node: node)
    when "pointer_add"
      accept_call_members(node)
      return unless @wants_value

      pointer_instance_type = owner.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type

      pointer_add(inner_sizeof_type(element_type), node: node)
    when "class"
      # Should match Crystal::Repl::Value#runtime_type
      # in src/compiler/crystal/interpreter/value.cr
      obj = obj.not_nil!
      type = obj.type.remove_indirection

      case type
      when VirtualType
        obj.accept self
        return unless @wants_value

        put_metaclass aligned_sizeof_type(type), false, node: node
      when UnionType
        obj.accept self
        return unless @wants_value

        put_metaclass aligned_sizeof_type(type), true, node: node
      else
        discard_value obj
        return unless @wants_value

        put_type type, node: node
      end
    when "object_crystal_type_id"
      unless @wants_value
        discard_value obj if obj
        return
      end

      if owner.is_a?(VirtualMetaclassType)
        # For a virtual metaclass type, the value is already an int
        # that's exactly the crystal_type_id, so there's nothing else to do.
        if obj
          request_obj_and_cast_if_needed(obj, owner)
        else
          put_self node: node
        end
      else
        put_i32 type_id(owner), node: node
      end
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
    when "pre_initialize"
      type =
        if obj
          discard_value(obj)
          obj.type.instance_type
        else
          scope.instance_type
        end

      accept_call_members(node)

      dup sizeof(Pointer(Void)), node: nil
      reset_class(aligned_instance_sizeof_type(type), type_id(type), node: node)

      initializer_compiled_defs = @context.type_instance_var_initializers(type)
      unless initializer_compiled_defs.empty?
        initializer_compiled_defs.size.times do
          dup sizeof(Pointer(Void)), node: nil
        end

        initializer_compiled_defs.each do |compiled_def|
          call compiled_def, node: nil
        end
      end
    when "tuple_indexer_known_index"
      unless @wants_value
        accept_call_members(node)
        return
      end

      type = owner
      case type
      when TupleInstanceType
        request_obj_or_self_and_cast_if_needed(node, obj, type)
        index = body.as(TupleIndexer).index
        case index
        in Int32
          element_type = type.tuple_types[index]
          offset = @context.offset_of(type, index)
          tuple_indexer_known_index(aligned_sizeof_type(type), offset, inner_sizeof_type(element_type), node: node)
        in Range
          element_type = @context.program.tuple_of(type.tuple_types[index].map &.as(Type))
          tuple_size = aligned_sizeof_type(type)
          index.each do |i|
            old_offset = @context.offset_of(type, i)
            new_offset = @context.offset_of(element_type, i - index.begin)
            element_size = inner_sizeof_type(type.tuple_types[i])
            tuple_copy_element(tuple_size, old_offset, new_offset, element_size, node: node)
          end
          value_size = inner_sizeof_type(element_type)
          pop(tuple_size - value_size, node: node)
          push_zeros(aligned_sizeof_type(element_type) - value_size, node: node)
        end
      when NamedTupleInstanceType
        request_obj_or_self_and_cast_if_needed(node, obj, type)
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
        discard_value obj if obj
        type = type.instance_type
        case type
        when TupleInstanceType
          index = body.as(TupleIndexer).index
          case index
          in Int32
            put_type(type.tuple_types[index].as(Type).metaclass, node: node)
          in Range
            put_type(@context.program.tuple_of(type.tuple_types[index].map &.as(Type)), node: node)
          end
        when NamedTupleInstanceType
          index = body.as(TupleIndexer).index
          case index
          when Int32
            put_type(type.entries[index].type.as(Type).metaclass, node: node)
          else
            node.raise "BUG: missing handling of primitive #{body.name} with range"
          end
        else
          node.raise "BUG: missing handling of primitive #{body.name} for #{type}"
        end
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
      proc_type = owner.as(ProcInstanceType)

      node.args.each_with_index do |arg, arg_index|
        request_value(arg)

        # Cast call argument to proc's type
        # (this same logic is done in codegen/primitives.cr)
        proc_arg_type = proc_type.arg_types[arg_index]
        target_def_arg_type = target_def.args[arg_index].type
        if proc_arg_type != target_def_arg_type
          upcast(arg, target_def_arg_type, proc_arg_type)
        end
      end

      if obj
        request_obj_and_cast_if_needed(obj, owner)
      else
        put_self(node: node)
      end

      proc_call(node: node)

      pop(aligned_sizeof_type(node.type), node: nil) unless @wants_value
    when "load_atomic"
      accept_call_args(node)

      pointer_instance_type = node.args.first.type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      load_atomic(element_size, node: node)
    when "store_atomic"
      accept_call_args(node)

      pointer_instance_type = node.args.first.type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      store_atomic(element_size, node: node)
    when "atomicrmw"
      accept_call_args(node)

      pointer_instance_type = node.args[1].type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      atomicrmw(element_size, node: node)
    when "cmpxchg"
      accept_call_args(node)

      pointer_instance_type = node.args[0].type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = inner_sizeof_type(element_type)

      cmpxchg(element_size, node: node)
    when "external_var_get"
      return unless @wants_value

      external = node.target_def.as(External)

      fn = @context.c_function(external.real_name)

      # Put the symbol address, which is a pointer
      put_u64 fn.address, node: node

      # Read from the pointer
      pointer_get(inner_sizeof_type(node), node: node)
    when "external_var_set"
      external = node.target_def.as(External)

      # pointer_set needs first arg, then obj
      arg = node.args.first
      request_value(arg)
      dup(aligned_sizeof_type(arg), node: nil) if @wants_value

      fn = @context.c_function(external.real_name)

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
    when "interpreter_fiber_resumable"
      accept_call_args(node)
      interpreter_fiber_resumable(node: node)
    when "interpreter_signal_descriptor"
      accept_call_args(node)
      interpreter_signal_descriptor(node: node)
    when "interpreter_signal"
      accept_call_args(node)
      interpreter_signal(node: node)
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
    when "interpreter_intrinsics_bswap16"
      accept_call_args(node)
      interpreter_intrinsics_bswap16(node: node)
    when "interpreter_intrinsics_bswap32"
      accept_call_args(node)
      interpreter_intrinsics_bswap32(node: node)
    when "interpreter_intrinsics_bswap64"
      accept_call_args(node)
      interpreter_intrinsics_bswap64(node: node)
    when "interpreter_intrinsics_bswap128"
      accept_call_args(node)
      interpreter_intrinsics_bswap128(node: node)
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
    when "interpreter_intrinsics_popcount128"
      accept_call_args(node)
      interpreter_intrinsics_popcount128(node: node)
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
    when "interpreter_intrinsics_countleading128"
      accept_call_args(node)
      interpreter_intrinsics_countleading128(node: node)
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
    when "interpreter_intrinsics_counttrailing128"
      accept_call_args(node)
      interpreter_intrinsics_counttrailing128(node: node)
    when "interpreter_intrinsics_bitreverse8"
      accept_call_args(node)
      interpreter_intrinsics_bitreverse8(node: node)
    when "interpreter_intrinsics_bitreverse16"
      accept_call_args(node)
      interpreter_intrinsics_bitreverse16(node: node)
    when "interpreter_intrinsics_bitreverse32"
      accept_call_args(node)
      interpreter_intrinsics_bitreverse32(node: node)
    when "interpreter_intrinsics_bitreverse64"
      accept_call_args(node)
      interpreter_intrinsics_bitreverse64(node: node)
    when "interpreter_intrinsics_bitreverse128"
      accept_call_args(node)
      interpreter_intrinsics_bitreverse128(node: node)
    when "interpreter_intrinsics_fshl8"
      accept_call_args(node)
      interpreter_intrinsics_fshl8(node: node)
    when "interpreter_intrinsics_fshl16"
      accept_call_args(node)
      interpreter_intrinsics_fshl16(node: node)
    when "interpreter_intrinsics_fshl32"
      accept_call_args(node)
      interpreter_intrinsics_fshl32(node: node)
    when "interpreter_intrinsics_fshl64"
      accept_call_args(node)
      interpreter_intrinsics_fshl64(node: node)
    when "interpreter_intrinsics_fshl128"
      accept_call_args(node)
      interpreter_intrinsics_fshl128(node: node)
    when "interpreter_intrinsics_fshr8"
      accept_call_args(node)
      interpreter_intrinsics_fshr8(node: node)
    when "interpreter_intrinsics_fshr16"
      accept_call_args(node)
      interpreter_intrinsics_fshr16(node: node)
    when "interpreter_intrinsics_fshr32"
      accept_call_args(node)
      interpreter_intrinsics_fshr32(node: node)
    when "interpreter_intrinsics_fshr64"
      accept_call_args(node)
      interpreter_intrinsics_fshr64(node: node)
    when "interpreter_intrinsics_fshr128"
      accept_call_args(node)
      interpreter_intrinsics_fshr128(node: node)
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
    when "interpreter_libm_fma_f32"
      accept_call_args(node)
      libm_fma_f32 node: node
    when "interpreter_libm_fma_f64"
      accept_call_args(node)
      libm_fma_f64 node: node
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

  private def primitive_convert(node : ASTNode, body : Primitive, owner : Type, checked : Bool)
    obj = node.obj

    unless @wants_value
      discard_value(obj) if obj
      return
    end

    obj_type = owner
    request_obj_or_self_and_cast_if_needed(node, obj, obj_type)

    target_type = body.type

    primitive_convert(node, obj_type, target_type, checked: checked)
  end

  private def primitive_convert(node : ASTNode, from_type : IntegerType | FloatType, to_type : IntegerType | FloatType, checked : Bool)
    from_kind = integer_or_float_kind(from_type)
    to_kind = integer_or_float_kind(to_type)

    unless from_kind && to_kind
      node.raise "BUG: missing handling of unchecked_convert for #{from_type} (#{node})"
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

  private def primitive_convert(node : ASTNode, from_kind : NumberKind, to_kind : NumberKind, checked : Bool)
    # Most of these are nop because we align the stack to 64 bits,
    # so numbers are already converted to 64 bits
    case {from_kind, to_kind}
    in {.i8?, .i8?}     then nop
    in {.i8?, .i16?}    then sign_extend(7, node: node)
    in {.i8?, .i32?}    then sign_extend(7, node: node)
    in {.i8?, .i64?}    then sign_extend(7, node: node)
    in {.i8?, .i128?}   then sign_extend(15, node: node)
    in {.i8?, .u8?}     then checked ? (sign_extend(7, node: node); i64_to_u8(node: node)) : nop
    in {.i8?, .u16?}    then sign_extend(7, node: node); checked ? i64_to_u16(node: node) : nop
    in {.i8?, .u32?}    then sign_extend(7, node: node); checked ? i64_to_u32(node: node) : nop
    in {.i8?, .u64?}    then sign_extend(7, node: node); checked ? i64_to_u64(node: node) : nop
    in {.i8?, .u128?}   then sign_extend(15, node: node); checked ? i128_to_u128(node: node) : nop
    in {.i8?, .f32?}    then sign_extend(7, node: node); i64_to_f32(node: node)
    in {.i8?, .f64?}    then sign_extend(7, node: node); i64_to_f64(node: node)
    in {.u8?, .i8?}     then zero_extend(7, node: node); checked ? u64_to_i8(node: node) : nop
    in {.u8?, .i16?}    then zero_extend(7, node: node)
    in {.u8?, .i32?}    then zero_extend(7, node: node)
    in {.u8?, .i64?}    then zero_extend(7, node: node)
    in {.u8?, .i128?}   then zero_extend(15, node: node)
    in {.u8?, .u8?}     then nop
    in {.u8?, .u16?}    then zero_extend(7, node: node)
    in {.u8?, .u32?}    then zero_extend(7, node: node)
    in {.u8?, .u64?}    then zero_extend(7, node: node)
    in {.u8?, .u128?}   then zero_extend(15, node: node)
    in {.u8?, .f32?}    then zero_extend(7, node: node); u64_to_f32(node: node)
    in {.u8?, .f64?}    then zero_extend(7, node: node); u64_to_f64(node: node)
    in {.i16?, .i8?}    then checked ? (sign_extend(6, node: node); i64_to_i8(node: node)) : nop
    in {.i16?, .i16?}   then nop
    in {.i16?, .i32?}   then sign_extend(6, node: node)
    in {.i16?, .i64?}   then sign_extend(6, node: node)
    in {.i16?, .i128?}  then sign_extend(14, node: node)
    in {.i16?, .u8?}    then checked ? (sign_extend(6, node: node); i64_to_u8(node: node)) : nop
    in {.i16?, .u16?}   then checked ? (sign_extend(6, node: node); i64_to_u16(node: node)) : nop
    in {.i16?, .u32?}   then sign_extend(6, node: node); checked ? i64_to_u32(node: node) : nop
    in {.i16?, .u64?}   then sign_extend(6, node: node); checked ? i64_to_u64(node: node) : nop
    in {.i16?, .u128?}  then sign_extend(14, node: node); checked ? i128_to_u128(node: node) : nop
    in {.i16?, .f32?}   then sign_extend(6, node: node); i64_to_f32(node: node)
    in {.i16?, .f64?}   then sign_extend(6, node: node); i64_to_f64(node: node)
    in {.u16?, .i8?}    then checked ? (zero_extend(6, node: node); u64_to_i8(node: node)) : nop
    in {.u16?, .i16?}   then checked ? (zero_extend(6, node: node); u64_to_i16(node: node)) : nop
    in {.u16?, .i32?}   then zero_extend(6, node: node)
    in {.u16?, .i64?}   then zero_extend(6, node: node)
    in {.u16?, .i128?}  then zero_extend(14, node: node)
    in {.u16?, .u8?}    then checked ? (zero_extend(6, node: node); u64_to_u8(node: node)) : nop
    in {.u16?, .u16?}   then nop
    in {.u16?, .u32?}   then zero_extend(6, node: node)
    in {.u16?, .u64?}   then zero_extend(6, node: node)
    in {.u16?, .u128?}  then zero_extend(14, node: node)
    in {.u16?, .f32?}   then zero_extend(6, node: node); u64_to_f32(node: node)
    in {.u16?, .f64?}   then zero_extend(6, node: node); u64_to_f64(node: node)
    in {.i32?, .i8?}    then checked ? (sign_extend(4, node: node); i64_to_i8(node: node)) : nop
    in {.i32?, .i16?}   then checked ? (sign_extend(4, node: node); i64_to_i16(node: node)) : nop
    in {.i32?, .i32?}   then nop
    in {.i32?, .i64?}   then sign_extend(4, node: node)
    in {.i32?, .i128?}  then sign_extend(12, node: node)
    in {.i32?, .u8?}    then checked ? (sign_extend(4, node: node); i64_to_u8(node: node)) : nop
    in {.i32?, .u16?}   then checked ? (sign_extend(4, node: node); i64_to_u16(node: node)) : nop
    in {.i32?, .u32?}   then checked ? (sign_extend(4, node: node); i64_to_u32(node: node)) : nop
    in {.i32?, .u64?}   then checked ? (sign_extend(4, node: node); i64_to_u64(node: node)) : sign_extend(4, node: node)
    in {.i32?, .u128?}  then checked ? (sign_extend(12, node: node); i128_to_u128(node: node)) : sign_extend(12, node: node)
    in {.i32?, .f32?}   then sign_extend(4, node: node); i64_to_f32(node: node)
    in {.i32?, .f64?}   then sign_extend(4, node: node); i64_to_f64(node: node)
    in {.u32?, .i8?}    then checked ? (zero_extend(4, node: node); u64_to_i8(node: node)) : nop
    in {.u32?, .i16?}   then checked ? (zero_extend(4, node: node); u64_to_i16(node: node)) : nop
    in {.u32?, .i32?}   then checked ? (zero_extend(4, node: node); u64_to_i32(node: node)) : nop
    in {.u32?, .i64?}   then zero_extend(4, node: node)
    in {.u32?, .i128?}  then zero_extend(12, node: node)
    in {.u32?, .u8?}    then checked ? (zero_extend(4, node: node); u64_to_u8(node: node)) : nop
    in {.u32?, .u16?}   then checked ? (zero_extend(4, node: node); u64_to_u16(node: node)) : nop
    in {.u32?, .u32?}   then nop
    in {.u32?, .u64?}   then zero_extend(4, node: node)
    in {.u32?, .u128?}  then zero_extend(12, node: node)
    in {.u32?, .f32?}   then zero_extend(4, node: node); u64_to_f32(node: node)
    in {.u32?, .f64?}   then zero_extend(4, node: node); u64_to_f64(node: node)
    in {.i64?, .i8?}    then checked ? i64_to_i8(node: node) : nop
    in {.i64?, .i16?}   then checked ? i64_to_i16(node: node) : nop
    in {.i64?, .i32?}   then checked ? i64_to_i32(node: node) : nop
    in {.i64?, .i64?}   then nop
    in {.i64?, .i128?}  then sign_extend(8, node: node)
    in {.i64?, .u8?}    then checked ? i64_to_u8(node: node) : nop
    in {.i64?, .u16?}   then checked ? i64_to_u16(node: node) : nop
    in {.i64?, .u32?}   then checked ? i64_to_u32(node: node) : nop
    in {.i64?, .u64?}   then checked ? i64_to_u64(node: node) : nop
    in {.i64?, .u128?}  then checked ? (sign_extend(8, node: node); i128_to_u128(node: node)) : sign_extend(8, node: node)
    in {.i64?, .f32?}   then i64_to_f32(node: node)
    in {.i64?, .f64?}   then i64_to_f64(node: node)
    in {.u64?, .i8?}    then checked ? u64_to_i8(node: node) : nop
    in {.u64?, .i16?}   then checked ? u64_to_i16(node: node) : nop
    in {.u64?, .i32?}   then checked ? u64_to_i32(node: node) : nop
    in {.u64?, .i64?}   then checked ? u64_to_i64(node: node) : nop
    in {.u64?, .i128?}  then zero_extend(8, node: node)
    in {.u64?, .u8?}    then checked ? u64_to_u8(node: node) : nop
    in {.u64?, .u16?}   then checked ? u64_to_u16(node: node) : nop
    in {.u64?, .u32?}   then checked ? u64_to_u32(node: node) : nop
    in {.u64?, .u64?}   then nop
    in {.u64?, .u128?}  then zero_extend(8, node: node)
    in {.u64?, .f32?}   then u64_to_f32(node: node)
    in {.u64?, .f64?}   then u64_to_f64(node: node)
    in {.i128?, .i8?}   then checked ? i128_to_i8(node: node) : pop(8, node: node)
    in {.i128?, .i16?}  then checked ? i128_to_i16(node: node) : pop(8, node: node)
    in {.i128?, .i32?}  then checked ? i128_to_i32(node: node) : pop(8, node: node)
    in {.i128?, .i64?}  then checked ? i128_to_i64(node: node) : pop(8, node: node)
    in {.i128?, .i128?} then nop
    in {.i128?, .u8?}   then checked ? i128_to_u8(node: node) : pop(8, node: node)
    in {.i128?, .u16?}  then checked ? i128_to_u16(node: node) : pop(8, node: node)
    in {.i128?, .u32?}  then checked ? i128_to_u32(node: node) : pop(8, node: node)
    in {.i128?, .u64?}  then checked ? i128_to_u64(node: node) : pop(8, node: node)
    in {.i128?, .u128?} then checked ? i128_to_u128(node: node) : nop
    in {.i128?, .f32?}  then i128_to_f32(node: node)
    in {.i128?, .f64?}  then i128_to_f64(node: node)
    in {.u128?, .i8?}   then checked ? u128_to_i8(node: node) : pop(8, node: node)
    in {.u128?, .i16?}  then checked ? u128_to_i16(node: node) : pop(8, node: node)
    in {.u128?, .i32?}  then checked ? u128_to_i32(node: node) : pop(8, node: node)
    in {.u128?, .i64?}  then checked ? u128_to_i64(node: node) : pop(8, node: node)
    in {.u128?, .i128?} then checked ? u128_to_i128(node: node) : nop
    in {.u128?, .u8?}   then checked ? u128_to_u8(node: node) : pop(8, node: node)
    in {.u128?, .u16?}  then checked ? u128_to_u16(node: node) : pop(8, node: node)
    in {.u128?, .u32?}  then checked ? u128_to_u32(node: node) : pop(8, node: node)
    in {.u128?, .u64?}  then checked ? u128_to_u64(node: node) : pop(8, node: node)
    in {.u128?, .u128?} then nop
    in {.u128?, .f32?}  then checked ? u128_to_f32(node: node) : u128_to_f32_bang(node: node)
    in {.u128?, .f64?}  then u128_to_f64(node: node)
    in {.f32?, .i8?}    then f32_to_f64(node: node); checked ? f64_to_i8(node: node) : f64_to_i64_bang(node: node)
    in {.f32?, .i16?}   then f32_to_f64(node: node); checked ? f64_to_i16(node: node) : f64_to_i64_bang(node: node)
    in {.f32?, .i32?}   then f32_to_f64(node: node); checked ? f64_to_i32(node: node) : f64_to_i64_bang(node: node)
    in {.f32?, .i64?}   then f32_to_f64(node: node); checked ? f64_to_i64(node: node) : f64_to_i64_bang(node: node)
    in {.f32?, .i128?}  then f32_to_f64(node: node); checked ? f64_to_i128(node: node) : f64_to_i128_bang(node: node)
    in {.f32?, .u8?}    then f32_to_f64(node: node); checked ? f64_to_u8(node: node) : f64_to_i64_bang(node: node)
    in {.f32?, .u16?}   then f32_to_f64(node: node); checked ? f64_to_u16(node: node) : f64_to_i64_bang(node: node)
    in {.f32?, .u32?}   then checked ? (f32_to_f64(node: node); f64_to_u32(node: node)) : f32_to_u32_bang(node: node)
    in {.f32?, .u64?}   then checked ? (f32_to_f64(node: node); f64_to_u64(node: node)) : f32_to_u64_bang(node: node)
    in {.f32?, .u128?}  then f32_to_f64(node: node); checked ? f64_to_u128(node: node) : f64_to_i128_bang(node: node)
    in {.f32?, .f32?}   then nop
    in {.f32?, .f64?}   then f32_to_f64(node: node)
    in {.f64?, .i8?}    then checked ? f64_to_i8(node: node) : f64_to_i64_bang(node: node)
    in {.f64?, .i16?}   then checked ? f64_to_i16(node: node) : f64_to_i64_bang(node: node)
    in {.f64?, .i32?}   then checked ? f64_to_i32(node: node) : f64_to_i64_bang(node: node)
    in {.f64?, .i64?}   then checked ? f64_to_i64(node: node) : f64_to_i64_bang(node: node)
    in {.f64?, .i128?}  then checked ? f64_to_i128(node: node) : f64_to_i128_bang(node: node)
    in {.f64?, .u8?}    then checked ? f64_to_u8(node: node) : f64_to_i64_bang(node: node)
    in {.f64?, .u16?}   then checked ? f64_to_u16(node: node) : f64_to_i64_bang(node: node)
    in {.f64?, .u32?}   then checked ? f64_to_u32(node: node) : f64_to_u32_bang(node: node)
    in {.f64?, .u64?}   then checked ? f64_to_u64(node: node) : f64_to_u64_bang(node: node)
    in {.f64?, .u128?}  then checked ? f64_to_u128(node: node) : f64_to_i128_bang(node: node)
    in {.f64?, .f32?}   then checked ? f64_to_f32(node: node) : f64_to_f32_bang(node: node)
    in {.f64?, .f64?}   then nop
    end
  end

  private def primitive_binary(node, body, owner)
    unless @wants_value
      accept_call_members(node)
      return
    end

    case node.name
    when "+", "&+", "-", "&-", "*", "&*", "^", "|", "&", "unsafe_shl", "unsafe_shr", "unsafe_div", "unsafe_mod"
      primitive_binary_op_math(node, body, owner, node.name)
    when "<", "<=", ">", ">=", "==", "!="
      primitive_binary_op_cmp(node, body, owner, node.name)
    when "/", "fdiv"
      primitive_binary_float_div(node, body, owner)
    else
      node.raise "BUG: missing handling of binary op #{node.name}"
    end
  end

  private def primitive_binary_op_math(node : ASTNode, body : Primitive, owner : Type, op : String)
    obj = node.obj
    arg = node.args.first

    obj_type = owner
    arg_type = arg.type

    primitive_binary_op_math(obj_type, arg_type, obj, arg, node, op)
  end

  private def primitive_binary_op_math(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    kind = extend_int(left_type, right_type, left_node, right_node, node)
    if kind.is_a?(MixedNumberKind)
      case kind
      in .mixed64?
        if left_type.rank > right_type.rank
          # It's UInt64 op X where X is a signed integer
          request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
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

          kind = NumberKind::U64
        else
          # It's X op UInt64 where X is a signed integer
          request_obj_or_self_and_cast_if_needed(node, left_node, left_type)

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

          kind = NumberKind::I64
        end
      in .mixed128?
        if left_type.rank > right_type.rank
          # It's UInt128 op X where X is a signed integer
          request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
          right_node.accept self

          # TODO: do we need to check for overflow here?
          primitive_convert(node, right_type.kind, :i128, checked: false)

          case node.name
          when "+"          then add_u128_i128(node: node)
          when "&+"         then add_wrap_i128(node: node)
          when "-"          then sub_u128_i128(node: node)
          when "&-"         then sub_wrap_i128(node: node)
          when "*"          then mul_u128_i128(node: node)
          when "&*"         then mul_wrap_i128(node: node)
          when "^"          then xor_i128(node: node)
          when "|"          then or_i128(node: node)
          when "&"          then and_i128(node: node)
          when "unsafe_shl" then unsafe_shl_i128(node: node)
          when "unsafe_shr" then unsafe_shr_u128_i128(node: node)
          when "unsafe_div" then unsafe_div_u128_i128(node: node)
          when "unsafe_mod" then unsafe_mod_u128_i128(node: node)
          else
            node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
          end

          kind = NumberKind::U128
        else
          # It's X op UInt128 where X is a signed integer
          request_obj_or_self_and_cast_if_needed(node, left_node, left_type)

          # TODO: do we need to check for overflow here?
          primitive_convert(node, left_type.kind, :i128, checked: false)
          right_node.accept self

          case node.name
          when "+"          then add_i128_u128(node: node)
          when "&+"         then add_wrap_i128(node: node)
          when "-"          then sub_i128_u128(node: node)
          when "&-"         then sub_wrap_i128(node: node)
          when "*"          then mul_i128_u128(node: node)
          when "&*"         then mul_wrap_i128(node: node)
          when "^"          then xor_i128(node: node)
          when "|"          then or_i128(node: node)
          when "&"          then and_i128(node: node)
          when "unsafe_shl" then unsafe_shl_i128(node: node)
          when "unsafe_shr" then unsafe_shr_i128_u128(node: node)
          when "unsafe_div" then unsafe_div_i128_u128(node: node)
          when "unsafe_mod" then unsafe_mod_i128_u128(node: node)
          else
            node.raise "BUG: missing handling of binary #{op} with types #{left_type} and #{right_type}"
          end

          kind = NumberKind::I128
        end
      end
    else
      # Go on
      return false unless @wants_value

      primitive_binary_op_math(node, kind, op)
    end

    if kind != left_type.kind
      checked = node.name.in?("+", "-", "*")
      primitive_convert(node, kind, left_type.kind, checked: checked)
    end
  end

  private def primitive_binary_op_math(left_type : IntegerType, right_type : FloatType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
    primitive_convert node, left_type.kind, right_type.kind, checked: false
    right_node.accept self

    primitive_binary_op_math(node, right_type.kind, op)
  end

  private def primitive_binary_op_math(left_type : FloatType, right_type : IntegerType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
    right_node.accept self
    primitive_convert right_node, right_type.kind, left_type.kind, checked: false

    primitive_binary_op_math(node, left_type.kind, op)
  end

  private def primitive_binary_op_math(left_type : FloatType, right_type : FloatType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode, op : String)
    if left_type == right_type
      request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
      right_node.accept self
      kind = left_type.kind
    elsif left_type.rank < right_type.rank
      # TODO: not tested
      request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
      primitive_convert node, left_type.kind, right_type.kind, checked: false
      right_node.accept self
      kind = right_type.kind
    else
      # TODO: not tested
      request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
      right_node.accept self
      primitive_convert right_node, right_type.kind, left_type.kind, checked: false
      kind = left_type.kind
    end

    primitive_binary_op_math(node, kind, op)

    if kind != left_type.kind
      primitive_convert(node, kind, left_type.kind, checked: false)
    end
  end

  private def primitive_binary_op_math(node : ASTNode, kind : NumberKind, op : String)
    case kind
    when .i32?
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
    when .u32?
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
    when .i64?
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
    when .u64?
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
    when .i128?
      case op
      when "+"          then add_i128(node: node)
      when "&+"         then add_wrap_i128(node: node)
      when "-"          then sub_i128(node: node)
      when "&-"         then sub_wrap_i128(node: node)
      when "*"          then mul_i128(node: node)
      when "&*"         then mul_wrap_i128(node: node)
      when "^"          then xor_i128(node: node)
      when "|"          then or_i128(node: node)
      when "&"          then and_i128(node: node)
      when "unsafe_shl" then unsafe_shl_i128(node: node)
      when "unsafe_shr" then unsafe_shr_i128(node: node)
      when "unsafe_div" then unsafe_div_i128(node: node)
      when "unsafe_mod" then unsafe_mod_i128(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when .u128?
      case op
      when "+"          then add_u128(node: node)
      when "&+"         then add_wrap_i128(node: node)
      when "-"          then sub_u128(node: node)
      when "&-"         then sub_wrap_i128(node: node)
      when "*"          then mul_u128(node: node)
      when "&*"         then mul_wrap_i128(node: node)
      when "^"          then xor_i128(node: node)
      when "|"          then or_i128(node: node)
      when "&"          then and_i128(node: node)
      when "unsafe_shl" then unsafe_shl_i128(node: node)
      when "unsafe_shr" then unsafe_shr_u128(node: node)
      when "unsafe_div" then unsafe_div_u128(node: node)
      when "unsafe_mod" then unsafe_mod_u128(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when .f32?
      # TODO: not tested
      case op
      when "+" then add_f32(node: node)
      when "-" then sub_f32(node: node)
      when "*" then mul_f32(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
      end
    when .f64?
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

  private def primitive_binary_op_cmp(node : ASTNode, body : Primitive, owner : Type, op : String)
    obj = node.obj.not_nil!
    arg = node.args.first

    obj_type = owner
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
    if kind.is_a?(MixedNumberKind)
      case kind
      in .mixed64?
        if left_type.rank > right_type.rank
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
      in .mixed128?
        if left_type.rank > right_type.rank
          # It's UInt128 == X where X is a signed integer.

          # We first extend right to left
          left_node.accept self
          right_node.accept self

          # TODO: do we need to check for overflow here?
          primitive_convert right_node, right_type.kind, :i128, checked: false

          cmp_u128_i128(node: node)
        else
          # It's X < UInt128 where X is a signed integer
          left_node.accept self

          # TODO: do we need to check for overflow here?
          primitive_convert left_node, left_type.kind, :i128, checked: false

          right_node.accept self

          cmp_i128_u128(node: node)
        end
      end
    else
      case kind
      when .i32?  then cmp_i32(node: node)
      when .u32?  then cmp_u32(node: node)
      when .i64?  then cmp_i64(node: node)
      when .u64?  then cmp_u64(node: node)
      when .i128? then cmp_i128(node: node)
      when .u128? then cmp_u128(node: node)
      else
        node.raise "BUG: missing handling of binary #{op} for #{kind}"
      end
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

      kind = NumberKind::F64
    else
      left_node.accept self
      right_node.accept self
      primitive_convert(right_node, right_type.kind, left_type.kind, checked: false)

      kind = NumberKind::F64
    end

    primitive_binary_op_cmp_float(node, kind, op)
  end

  private def primitive_binary_op_cmp(left_type : Type, right_type : Type, left_node : ASTNode, right_node : ASTNode, node : ASTNode, op : String)
    left_node.raise "BUG: primitive_binary_op_cmp called with #{left_type} #{op} #{right_type}"
  end

  private def primitive_binary_op_cmp_float(node : ASTNode, kind : NumberKind, op : String)
    if predicate = FloatPredicate.from_method?(op)
      case kind
      when .f32? then return cmp_f32(predicate, node: node)
      when .f64? then return cmp_f64(predicate, node: node)
      end
    end

    node.raise "BUG: missing handling of binary #{op} with kind #{kind}"
  end

  # TODO: should integer comparisons also use `FloatPredicate`?
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

  # interpreter-exclusive flags for `cmp_f32` and `cmp_f64`
  # currently compatible with `LLVM::RealPredicate`
  @[Flags]
  enum FloatPredicate : UInt8
    Equal
    GreaterThan
    LessThan
    Unordered

    def self.from_method?(op : String)
      case op
      when "==" then Equal
      when "!=" then LessThan | GreaterThan | Unordered
      when "<"  then LessThan
      when "<=" then LessThan | Equal
      when ">"  then GreaterThan
      when ">=" then GreaterThan | Equal
      end
    end

    def compare(x, y) : Bool
      (equal? && x == y) ||
        (greater_than? && x > y) ||
        (less_than? && x < y) ||
        (unordered? && (x.nan? || y.nan?))
    end
  end

  # interpreter-exclusive integer unions
  private enum MixedNumberKind
    # Int64 | UInt64
    Mixed64

    # Int128 | UInt128
    Mixed128
  end

  private def extend_int(left_type : IntegerType, right_type : IntegerType, left_node : ASTNode?, right_node : ASTNode, node : ASTNode)
    # We don't do operations "below" Int32, we always cast the values
    # to at least Int32. This might be slightly slower, but it allows
    # us to need less opcodes in the bytecode.
    if left_type.rank <= 5 && right_type.rank <= 5
      # If both fit in an Int32
      # Convert them to Int32 first, then do the comparison
      request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
      primitive_convert(left_node || right_node, left_type.kind, :i32, checked: false) if left_type.rank < 5

      right_node.accept self
      primitive_convert(right_node, right_type.kind, :i32, checked: false) if right_type.rank < 5

      NumberKind::I32
    elsif left_type.signed? == right_type.signed?
      if left_type.rank == right_type.rank
        request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
        right_node.accept self
        left_type.kind
      elsif left_type.rank < right_type.rank
        request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
        primitive_convert(left_node || right_node, left_type.kind, right_type.kind, checked: false)
        right_node.accept self
        right_type.kind
      else
        request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
        right_node.accept self
        primitive_convert(right_node, right_type.kind, left_type.kind, checked: false)
        left_type.kind
      end
    elsif left_type.rank <= 7 && right_type.rank <= 7
      # If both fit in an Int64
      # Convert them to Int64 first, then do the comparison
      request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
      primitive_convert(left_node || right_node, left_type.kind, :i64, checked: false) if left_type.rank < 7

      right_node.accept self
      primitive_convert(right_node, right_type.kind, :i64, checked: false) if right_type.rank < 7

      NumberKind::I64
    elsif left_type.rank <= 8 && right_type.rank <= 8
      MixedNumberKind::Mixed64
    elsif left_type.rank <= 9 && right_type.rank <= 9
      # If both fit in an Int128
      # Convert them to Int128 first, then do the comparison
      request_obj_or_self_and_cast_if_needed(node, left_node, left_type)
      primitive_convert(left_node || right_node, left_type.kind, :i128, checked: false) if left_type.rank < 9

      right_node.accept self
      primitive_convert(right_node, right_type.kind, :i128, checked: false) if right_type.rank < 9

      NumberKind::I128
    else
      MixedNumberKind::Mixed128
    end
  end

  private def primitive_binary_float_div(node : ASTNode, body, owner : Type)
    # TODO: don't assume Float64 op Float64
    obj = node.obj.not_nil!
    arg = node.args.first

    obj_type = owner
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
    when {.f32?, .f32?}
      div_f32(node: node)
    when {.f64?, .f64?}
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

  private def request_obj_and_cast_if_needed(obj, owner)
    request_value(obj)

    obj_type = obj.try &.type?.try &.remove_indirection
    if obj_type && obj_type != owner
      downcast(obj, obj_type, owner)
    end
  end

  private def request_obj_or_self_and_cast_if_needed(node, obj, owner)
    if obj
      request_obj_and_cast_if_needed(obj, owner)
    else
      put_self(node: node)
    end
  end
end

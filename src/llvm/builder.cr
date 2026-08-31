class LLVM::Builder
  @disposed = false

  def initialize(@unwrap : LibLLVM::BuilderRef)
  end

  def position_at_end(block)
    LibLLVM.position_builder_at_end(self, block)
  end

  def insert_block
    BasicBlock.new LibLLVM.get_insert_block(self)
  end

  def ret
    Value.new LibLLVM.build_ret_void(self)
  end

  def ret(value)
    # check_value(value)

    Value.new LibLLVM.build_ret(self, value)
  end

  def br(block)
    Value.new LibLLVM.build_br(self, block)
  end

  def cond(cond, then_block, else_block)
    # check_value(cond)

    Value.new LibLLVM.build_cond(self, cond, then_block, else_block)
  end

  def phi(type, table : LLVM::PhiTable, name = "")
    # check_type("phi", type)

    phi type, table.blocks, table.values, name
  end

  def phi(type, incoming_blocks : Array(LLVM::BasicBlock), incoming_values : Array(LLVM::Value), name = "")
    # check_type("phi", type)

    phi_node = LibLLVM.build_phi self, type, name
    LibLLVM.add_incoming phi_node,
      (incoming_values.to_unsafe.as(LibLLVM::ValueRef*)),
      (incoming_blocks.to_unsafe.as(LibLLVM::BasicBlockRef*)),
      incoming_blocks.size
    Value.new phi_node
  end

  @[Deprecated("Pass the function type of `func` as well (equal to `func.function_type`) in order to support LLVM 15+")]
  def call(func : LLVM::Function, name : String = "")
    # check_func(func)

    Value.new LibLLVM.build_call2(self, func.function_type, func, nil, 0, name)
  end

  def call(type : LLVM::Type, func : LLVM::Function, name : String = "")
    # check_type("call", type)
    # check_func(func)

    Value.new LibLLVM.build_call2(self, type, func, nil, 0, name)
  end

  @[Deprecated("Pass the function type of `func` as well (equal to `func.function_type`) in order to support LLVM 15+")]
  def call(func : LLVM::Function, arg : LLVM::Value, name : String = "")
    # check_func(func)
    # check_value(arg)

    value = arg.to_unsafe
    Value.new LibLLVM.build_call2(self, func.function_type, func, pointerof(value), 1, name)
  end

  def call(type : LLVM::Type, func : LLVM::Function, arg : LLVM::Value, name : String = "")
    # check_type("call", type)
    # check_func(func)
    # check_value(arg)

    value = arg.to_unsafe
    Value.new LibLLVM.build_call2(self, type, func, pointerof(value), 1, name)
  end

  @[Deprecated("Pass the function type of `func` as well (equal to `func.function_type`) in order to support LLVM 15+")]
  def call(func : LLVM::Function, args : Array(LLVM::Value), name : String = "", bundle : LLVM::OperandBundleDef = LLVM::OperandBundleDef.null)
    # check_func(func)
    # check_values(args)

    bundle_ref = bundle.to_unsafe
    bundles = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new {{ LibLLVM::IS_LT_180 ? LibLLVMExt : LibLLVM }}.build_call_with_operand_bundles(self, func.function_type, func, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, bundles, num_bundles, name)
  end

  def call(type : LLVM::Type, func : LLVM::Function, args : Array(LLVM::Value), name : String = "")
    # check_type("call", type)
    # check_func(func)
    # check_values(args)

    Value.new LibLLVM.build_call2(self, type, func, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, name)
  end

  def call(type : LLVM::Type, func : LLVM::Function, args : Array(LLVM::Value), name : String, bundle : LLVM::OperandBundleDef)
    # check_type("call", type)
    # check_func(func)
    # check_values(args)

    bundle_ref = bundle.to_unsafe
    bundles = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new {{ LibLLVM::IS_LT_180 ? LibLLVMExt : LibLLVM }}.build_call_with_operand_bundles(self, type, func, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, bundles, num_bundles, name)
  end

  def call(type : LLVM::Type, func : LLVM::Function, args : Array(LLVM::Value), bundle : LLVM::OperandBundleDef)
    call(type, func, args, "", bundle)
  end

  def alloca(type, name = "")
    # check_type("alloca", type)

    Value.new LibLLVM.build_alloca(self, type, name)
  end

  def store(value, ptr)
    # check_value(value, "value")
    # check_value(ptr, "ptr")

    Value.new LibLLVM.build_store(self, value, ptr)
  end

  @[Deprecated("Pass the pointee of `ptr` as well (equal to `ptr.type.element_type`) in order to support LLVM 15+")]
  def load(ptr : LLVM::Value, name = "")
    # check_value(ptr)

    Value.new LibLLVM.build_load2(self, ptr.type.element_type, ptr, name)
  end

  def load(type : LLVM::Type, ptr : LLVM::Value, name = "")
    # check_type("load", type)
    # check_value(ptr)

    Value.new LibLLVM.build_load2(self, type, ptr, name)
  end

  def store_volatile(value, ptr)
    store(value, ptr).tap { |v| v.volatile = true }
  end

  def load_volatile(ptr : LLVM::Value, name = "")
    load(ptr, name).tap { |v| v.volatile = true }
  end

  def load_volatile(type : LLVM::Type, ptr : LLVM::Value, name = "")
    load(type, ptr, name).tap { |v| v.volatile = true }
  end

  {% for method_name in %w(gep inbounds_gep) %}
    @[Deprecated("Pass the type of `value` as well (equal to `value.type`) in order to support LLVM 15+")]
    def {{ method_name.id }}(value : LLVM::Value, indices : Array(LLVM::ValueRef), name = "")
      # check_value(value)

      Value.new LibLLVM.build_{{ method_name.id }}2(self, value.type, value, indices.to_unsafe.as(LibLLVM::ValueRef*), indices.size, name)
    end

    def {{ method_name.id }}(type : LLVM::Type, value : LLVM::Value, indices : Array(LLVM::ValueRef), name = "")
      # check_type({{ method_name }}, type)
      # check_value(value)

      Value.new LibLLVM.build_{{ method_name.id }}2(self, type, value, indices.to_unsafe.as(LibLLVM::ValueRef*), indices.size, name)
    end

    @[Deprecated("Pass the type of `value` as well (equal to `value.type`) in order to support LLVM 15+")]
    def {{ method_name.id }}(value : LLVM::Value, index : LLVM::Value, name = "")
      # check_value(value)

      indices = pointerof(index).as(LibLLVM::ValueRef*)
      Value.new LibLLVM.build_{{ method_name.id }}2(self, value.type, value, indices, 1, name)
    end

    def {{ method_name.id }}(type : LLVM::Type, value : LLVM::Value, index : LLVM::Value, name = "")
      # check_type({{ method_name }}, type)
      # check_value(value)

      indices = pointerof(index).as(LibLLVM::ValueRef*)
      Value.new LibLLVM.build_{{ method_name.id }}2(self, type, value, indices, 1, name)
    end

    @[Deprecated("Pass the type of `value` as well (equal to `value.type`) in order to support LLVM 15+")]
    def {{ method_name.id }}(value : LLVM::Value, index1 : LLVM::Value, index2 : LLVM::Value, name = "")
      # check_value(value)

      indices = uninitialized LLVM::Value[2]
      indices[0] = index1
      indices[1] = index2
      Value.new LibLLVM.build_{{ method_name.id }}2(self, value.type, value, indices.to_unsafe.as(LibLLVM::ValueRef*), 2, name)
    end

    def {{ method_name.id }}(type : LLVM::Type, value : LLVM::Value, index1 : LLVM::Value, index2 : LLVM::Value, name = "")
      # check_type({{ method_name }}, type)
      # check_value(value)

      indices = uninitialized LLVM::Value[2]
      indices[0] = index1
      indices[1] = index2
      Value.new LibLLVM.build_{{ method_name.id }}2(self, type, value, indices.to_unsafe.as(LibLLVM::ValueRef*), 2, name)
    end
  {% end %}

  def extract_value(value, index, name = "")
    # check_value(value)

    Value.new LibLLVM.build_extract_value(self, value, index, name)
  end

  {% for name in %w(bit_cast zext sext trunc fpext fptrunc fp2si fp2ui si2fp ui2fp int2ptr ptr2int) %}
    def {{ name.id }}(value, type, name = "")
      # check_type({{ name }}, type)
      # check_value(value)

      Value.new LibLLVM.build_{{ name.id }}(self, value, type, name)
    end
  {% end %}

  {% for name in %w(add sub mul sdiv exact_sdiv udiv srem urem shl ashr lshr or and xor fadd fsub fmul fdiv) %}
    def {{ name.id }}(lhs, rhs, name = "")
      # check_value(lhs)
      # check_value(rhs)

      Value.new LibLLVM.build_{{ name.id }}(self, lhs, rhs, name)
    end
  {% end %}

  {% for name in %w(icmp fcmp) %}
    def {{ name.id }}(op, lhs, rhs, name = "")
      # check_value(lhs)
      # check_value(rhs)

      Value.new LibLLVM.build_{{ name.id }}(self, op, lhs, rhs, name)
    end
  {% end %}

  {% for name in %w(not neg fneg) %}
    def {{ name.id }}(value, name = "")
      # check_value(value)

      Value.new LibLLVM.build_{{ name.id }}(self, value, name)
    end
  {% end %}

  def unreachable
    Value.new LibLLVM.build_unreachable(self)
  end

  def select(cond, a_then, a_else, name = "")
    # check_value(cond)
    # check_value(a_then)
    # check_value(a_else)

    Value.new LibLLVM.build_select self, cond, a_then, a_else, name
  end

  def global_string_pointer(string, name = "")
    Value.new LibLLVM.build_global_string_ptr self, string, name
  end

  def landing_pad(type, personality, clauses, name = "")
    # check_type("landing_pad", type)

    lpad = LibLLVM.build_landing_pad self, type, personality, clauses.size, name
    LibLLVM.set_cleanup lpad, 1
    clauses.each do |clause|
      LibLLVM.add_clause lpad, clause
    end
    Value.new lpad
  end

  def catch_switch(parent_pad, basic_block, num_handlers, name = "")
    Value.new LibLLVM.build_catch_switch(self, parent_pad, basic_block, num_handlers, name)
  end

  def catch_pad(parent_pad, args : Array(LLVM::Value), name = "")
    Value.new LibLLVM.build_catch_pad(self, parent_pad, args.to_unsafe.as(LibLLVM::ValueRef*), args.size, name)
  end

  def add_handler(catch_switch_ref, handler)
    LibLLVM.add_handler catch_switch_ref, handler
  end

  def build_operand_bundle_def(name, values : Array(LLVM::Value))
    LLVM::OperandBundleDef.new {{ LibLLVM::IS_LT_180 ? LibLLVMExt : LibLLVM }}.create_operand_bundle(name, name.bytesize, values.to_unsafe.as(LibLLVM::ValueRef*), values.size)
  end

  def build_catch_ret(pad, basic_block)
    LibLLVM.build_catch_ret(self, pad, basic_block)
  end

  @[Deprecated("Pass the function type of `fn` as well (equal to `fn.function_type`) in order to support LLVM 15+")]
  def invoke(fn : LLVM::Function, args : Array(LLVM::Value), a_then, a_catch, bundle : LLVM::OperandBundleDef = LLVM::OperandBundleDef.null, name = "")
    # check_func(fn)

    bundle_ref = bundle.to_unsafe
    bundles = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new {{ LibLLVM::IS_LT_180 ? LibLLVMExt : LibLLVM }}.build_invoke_with_operand_bundles(self, fn.function_type, fn, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, a_then, a_catch, bundles, num_bundles, name)
  end

  def invoke(type : LLVM::Type, fn : LLVM::Function, args : Array(LLVM::Value), a_then, a_catch, *, name = "")
    # check_type("invoke", type)
    # check_func(fn)

    Value.new LibLLVM.build_invoke2 self, type, fn, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, a_then, a_catch, name
  end

  def invoke(type : LLVM::Type, fn : LLVM::Function, args : Array(LLVM::Value), a_then, a_catch, bundle : LLVM::OperandBundleDef, name = "")
    # check_type("invoke", type)
    # check_func(fn)

    bundle_ref = bundle.to_unsafe
    bundles = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new {{ LibLLVM::IS_LT_180 ? LibLLVMExt : LibLLVM }}.build_invoke_with_operand_bundles(self, type, fn, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, a_then, a_catch, bundles, num_bundles, name)
  end

  def switch(value, otherwise, cases)
    # check_value(value)

    switch = LibLLVM.build_switch self, value, otherwise, cases.size
    cases.each do |case_value, block|
      LibLLVM.add_case switch, case_value, block
    end
    switch
  end

  def atomicrmw(op, ptr, val, ordering, singlethread)
    Value.new LibLLVM.build_atomicrmw(self, op, ptr, val, ordering, singlethread ? 1 : 0)
  end

  def cmpxchg(pointer, cmp, new, success_ordering, failure_ordering, singlethread : Bool = false)
    Value.new LibLLVM.build_atomic_cmp_xchg(self, pointer, cmp, new, success_ordering, failure_ordering, singlethread ? 1 : 0)
  end

  def fence(ordering, singlethread, name = "")
    Value.new LibLLVM.build_fence(self, ordering, singlethread ? 1 : 0, name)
  end

  def va_arg(list, type, name = "")
    Value.new LibLLVM.build_va_arg(self, list, type, name)
  end

  @[Deprecated("Call `#set_current_debug_location(metadata, context)` or `#clear_current_debug_location` instead")]
  def set_current_debug_location(line, column, scope, inlined_at = nil)
    LibLLVMExt.set_current_debug_location(self, line, column, scope, inlined_at)
  end

  def set_current_debug_location(metadata, context : LLVM::Context)
    {% if LibLLVM::IS_LT_90 %}
      LibLLVM.set_current_debug_location(self, LibLLVM.metadata_as_value(context, metadata))
    {% else %}
      LibLLVM.set_current_debug_location2(self, metadata)
    {% end %}
  end

  def clear_current_debug_location
    {% if LibLLVM::IS_LT_90 %}
      LibLLVMExt.clear_current_debug_location(self)
    {% else %}
      LibLLVM.set_current_debug_location2(self, nil)
    {% end %}
  end

  def set_metadata(value, kind, node)
    LibLLVM.set_metadata(value, kind, node)
  end

  def current_debug_location
    Value.new LibLLVM.get_current_debug_location(self)
  end

  def to_unsafe
    @unwrap
  end

  protected def dispose
    return if @disposed
    @disposed = true

    LibLLVM.dispose_builder(@unwrap)
  end

  def finalize
    dispose
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # private def check_type(name, type)
  #   if @context != type.context
  #     Context.wrong(@context, type.context, "wrong context for #{name}")
  #   end
  # end

  # private def check_func(func)
  #   # An instruction such as a bitcast to a function type can be passed
  #   # to build, and in that case there's no need to check for context equality
  #   return unless func.kind.function?

  #   context = LibLLVM.get_module_context(LibLLVM.get_global_parent(func))
  #   if @context.@unwrap != context
  #     Context.wrong(@context, LLVM::Context.new(context, dispose_on_finalize: false), "wrong context for #{func}")
  #   end
  # end

  # private def check_value(value, msg = nil)
  #   type = value.type
  #   ctx = type.context
  #   if @context != ctx
  #     Context.wrong(@context, ctx, "wrong context for value #{value} #{msg ? "(#{msg})" : ""}")
  #   end
  # end

  # private def check_values(values)
  #   values.each do |value|
  #     check_value(value)
  #   end
  # end
end

class LLVM::Builder
  def initialize
    @unwrap = LibLLVM.create_builder
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
    Value.new LibLLVM.build_ret(self, value)
  end

  def br(block)
    Value.new LibLLVM.build_br(self, block)
  end

  def cond(cond, then_block, else_block)
    Value.new LibLLVM.build_cond(self, cond, then_block, else_block)
  end

  def phi(type, table : LLVM::PhiTable, name = "")
    phi type, table.blocks, table.values, name
  end

  def phi(type, incoming_blocks : Array(LLVM::BasicBlock), incoming_values : Array(LLVM::Value), name = "")
    phi_node = LibLLVM.build_phi self, type, name
    LibLLVM.add_incoming phi_node,
      (incoming_values.to_unsafe.as(LibLLVM::ValueRef*)),
      (incoming_blocks.to_unsafe.as(LibLLVM::BasicBlockRef*)),
      incoming_blocks.size
    Value.new phi_node
  end

  def call(func, name : String = "")
    Value.new LibLLVM.build_call(self, func, nil, 0, name)
  end

  def call(func, arg : LLVM::Value, name : String = "")
    value = arg.to_unsafe
    Value.new LibLLVM.build_call(self, func, pointerof(value), 1, name)
  end

  def call(func, args : Array(LLVM::Value), name : String = "")
    Value.new LibLLVM.build_call(self, func, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, name)
  end

  def alloca(type, name = "")
    Value.new LibLLVM.build_alloca(self, type, name)
  end

  def store(value, ptr)
    Value.new LibLLVM.build_store(self, value, ptr)
  end

  def load(ptr, name = "")
    Value.new LibLLVM.build_load(self, ptr, name)
  end

  def malloc(type, name = "")
    Value.new LibLLVM.build_malloc(self, type, name)
  end

  def array_malloc(type, value, name = "")
    Value.new LibLLVM.build_array_malloc(self, type, value, name)
  end

  {% for method_name in %w(gep inbounds_gep) %}
    def {{method_name.id}}(value, indices : Array(LLVM::ValueRef), name = "")
      Value.new LibLLVM.build_{{method_name.id}}(self, value, indices.to_unsafe.as(LibLLVM::ValueRef*), indices.size, name)
    end

    def {{method_name.id}}(value, index : LLVM::Value, name = "")
      indices = pointerof(index).as(LibLLVM::ValueRef*)
      Value.new LibLLVM.build_{{method_name.id}}(self, value, indices, 1, name)
    end

    def {{method_name.id}}(value, index1 : LLVM::Value, index2 : LLVM::Value, name = "")
      indices = uninitialized LLVM::Value[2]
      indices[0] = index1
      indices[1] = index2
      Value.new LibLLVM.build_{{method_name.id}}(self, value, indices.to_unsafe.as(LibLLVM::ValueRef*), 2, name)
    end
  {% end %}

  def extract_value(value, index, name = "")
    Value.new LibLLVM.build_extract_value(self, value, index, name)
  end

  {% for name in %w(bit_cast si2fp ui2fp zext sext trunc fpext fptrunc fp2si fp2ui si2fp ui2fp int2ptr ptr2int) %}
    def {{name.id}}(value, type, name = "")
      Value.new LibLLVM.build_{{name.id}}(self, value, type, name)
    end
  {% end %}

  {% for name in %w(add sub mul sdiv exact_sdiv udiv srem urem shl ashr lshr or and xor fadd fsub fmul fdiv) %}
    def {{name.id}}(lhs, rhs, name = "")
      Value.new LibLLVM.build_{{name.id}}(self, lhs, rhs, name)
    end
  {% end %}

  {% for name in %w(icmp fcmp) %}
    def {{name.id}}(op, lhs, rhs, name = "")
      Value.new LibLLVM.build_{{name.id}}(self, op, lhs, rhs, name)
    end
  {% end %}

  def not(value, name = "")
    Value.new LibLLVM.build_not(self, value, name)
  end

  def unreachable
    Value.new LibLLVM.build_unreachable(self)
  end

  def select(cond, a_then, a_else, name = "")
    Value.new LibLLVM.build_select self, cond, a_then, a_else, name
  end

  def global_string_pointer(string, name = "")
    Value.new LibLLVM.build_global_string_ptr self, string, name
  end

  def landing_pad(type, personality, clauses, name = "")
    lpad = LibLLVM.build_landing_pad self, type, personality, clauses.size, name
    LibLLVM.set_cleanup lpad, 1
    clauses.each do |clause|
      LibLLVM.add_clause lpad, clause
    end
    Value.new lpad
  end

  def invoke(fn, args : Array(LLVM::Value), a_then, a_catch, name = "")
    Value.new LibLLVM.build_invoke self, fn, (args.to_unsafe.as(LibLLVM::ValueRef*)), args.size, a_then, a_catch, name
  end

  def switch(value, otherwise, cases)
    switch = LibLLVM.build_switch self, value, otherwise, cases.size
    cases.each do |case_value, block|
      LibLLVM.add_case switch, case_value, block
    end
    switch
  end

  def atomicrmw(op, ptr, val, ordering, singlethread)
    Value.new LibLLVM.build_atomicrmw(self, op, ptr, val, ordering, singlethread ? 1 : 0)
  end

  def cmpxchg(pointer, cmp, new, success_ordering, failure_ordering)
    Value.new LibLLVMExt.build_cmpxchg(self, pointer, cmp, new, success_ordering, failure_ordering)
  end

  def fence(ordering, singlethread, name = "")
    Value.new LibLLVM.build_fence(self, ordering, singlethread ? 1 : 0, name)
  end

  def set_current_debug_location(line, column, scope, inlined_at = nil)
    LibLLVMExt.set_current_debug_location(self, line, column, scope, inlined_at)
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

  def finalize
    LibLLVM.dispose_builder(@unwrap)
  end
end

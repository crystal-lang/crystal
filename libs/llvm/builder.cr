struct LLVM::Builder
  def initialize
    @unwrap = LibLLVM.create_builder
  end

  def position_at_end(block)
    LibLLVM.position_builder_at_end(self, block)
  end

  def insert_block
    LibLLVM.get_insert_block(self)
  end

  def ret
    LibLLVM.build_ret_void(self)
  end

  def ret(value)
    LibLLVM.build_ret(self, value)
  end

  def br(block)
    LibLLVM.build_br(self, block)
  end

  def cond(cond, then_block, else_block)
    LibLLVM.build_cond(self, cond, then_block, else_block)
  end

  def phi(type, table : LLVM::PhiTable, name = "")
    phi type, table.blocks, table.values, name
  end

  def phi(type, incoming_blocks, incoming_values, name = "")
    phi_node = LibLLVM.build_phi self, type, name
    LibLLVM.add_incoming phi_node, incoming_values.buffer, incoming_blocks.buffer, incoming_blocks.length
    phi_node
  end

  def call(func, args = [] of LibLLVM::ValueRef)
    LibLLVM.build_call(self, func, args.buffer, args.length, "")
  end

  def alloca(type, name = "")
    LibLLVM.build_alloca(self, type, name)
  end

  def store(value, ptr)
    LibLLVM.build_store(self, value, ptr)
  end

  def load(ptr, name = "")
    LibLLVM.build_load(self, ptr, name)
  end

  def malloc(type, name = "")
    LibLLVM.build_malloc(self, type, name)
  end

  def array_malloc(type, value, name = "")
    LibLLVM.build_array_malloc(self, type, value, name)
  end

  def gep(value, indices, name = "")
    LibLLVM.build_gep(self, value, indices.buffer, indices.length.to_u32, name)
  end

  def inbounds_gep(value, indices, name = "")
    LibLLVM.build_inbounds_gep(self, value, indices.buffer, indices.length.to_u32, name)
  end

  def extract_value(value, index, name = "")
    LibLLVM.build_extract_value(self, value, index.to_u32, name)
  end

  {% for name in %w(bit_cast si2fp ui2fp zext sext trunc fpext fptrunc fp2si fp2ui si2fp ui2fp int2ptr ptr2int) %}
    def {{name.id}}(value, type, name = "")
      LibLLVM.build_{{name.id}}(self, value, type, name)
    end
  {% end %}

  {% for name in %w(add sub mul sdiv exact_sdiv udiv srem urem shl ashr lshr or and xor fadd fsub fmul fdiv) %}
    def {{name.id}}(lhs, rhs, name = "")
      LibLLVM.build_{{name.id}}(self, lhs, rhs, name)
    end
  {% end %}

  {% for name in %w(icmp fcmp) %}
    def {{name.id}}(op, lhs, rhs, name = "")
      LibLLVM.build_{{name.id}}(self, op, lhs, rhs, name)
    end
  {% end %}

  def not(value, name = "")
    LibLLVM.build_not(self, value, name)
  end

  def unreachable
    LibLLVM.build_unreachable(self)
  end

  def select(cond, a_then, a_else, name = "")
    LibLLVM.build_select self, cond, a_then, a_else, name
  end

  def global_string_pointer(string, name = "")
    LibLLVM.build_global_string_ptr self, string, name
  end

  def landing_pad(type, personality, clauses, name = "")
    lpad = LibLLVM.build_landing_pad self, type, personality, clauses.length.to_u32, name
    LibLLVM.set_cleanup lpad, 1
    clauses.each do |clause|
      LibLLVM.add_clause lpad, clause
    end
    lpad
  end

  def invoke(fn, args, a_then, a_catch, name = "")
    LibLLVM.build_invoke self, fn, args.buffer, args.length.to_u32, a_then, a_catch, name
  end
end

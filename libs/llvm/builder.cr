require "wrapper"

struct LLVM::Builder
  include LLVM::Wrapper

  def initialize
    @builder = LibLLVM.create_builder
  end

  def wrapped_pointer
    @builder
  end

  def position_at_end(block)
    LibLLVM.position_builder_at_end(@builder, block)
  end

  def insert_block
    LibLLVM.get_insert_block(@builder)
  end

  def ret
    LibLLVM.build_ret_void(@builder)
  end

  def ret(value)
    LibLLVM.build_ret(@builder, value)
  end

  def br(block)
    LibLLVM.build_br(@builder, block)
  end

  def cond(cond, then_block, else_block)
    LibLLVM.build_cond(@builder, cond, then_block, else_block)
  end

  def phi(type, table : LLVM::PhiTable, name = "")
    phi type, table.blocks, table.values, name
  end

  def phi(type, incoming_blocks, incoming_values, name = "")
    phi_node = LibLLVM.build_phi @builder, type, name
    LibLLVM.add_incoming phi_node, incoming_values.buffer, incoming_blocks.buffer, incoming_blocks.length
    phi_node
  end

  def call(func : Function, args = [] of LibLLVM::ValueRef)
    call(func.llvm_function, args)
  end

  def call(func : LibLLVM::ValueRef, args = [] of LibLLVM::ValueRef)
    LibLLVM.build_call(@builder, func, args.buffer, args.length, "")
  end

  def alloca(type, name = "")
    LibLLVM.build_alloca(@builder, type, name)
  end

  def store(value, ptr)
    LibLLVM.build_store(@builder, value, ptr)
  end

  def load(ptr, name = "")
    LibLLVM.build_load(@builder, ptr, name)
  end

  def malloc(type, name = "")
    LibLLVM.build_malloc(@builder, type, name)
  end

  def array_malloc(type, value, name = "")
    LibLLVM.build_array_malloc(@builder, type, value, name)
  end

  def gep(value, indices, name = "")
    LibLLVM.build_gep(@builder, value, indices.buffer, indices.length.to_u32, name)
  end

  def inbounds_gep(value, indices, name = "")
    LibLLVM.build_inbounds_gep(@builder, value, indices.buffer, indices.length.to_u32, name)
  end

  def extract_value(value, index, name = "")
    LibLLVM.build_extract_value(@builder, value, index.to_u32, name)
  end

  macro self.define_cast(name)"
    def #{name}(value, type, name = \"\")
      LibLLVM.build_#{name}(@builder, value, type, name)
    end
  "end

  define_cast bit_cast
  define_cast si2fp
  define_cast ui2fp
  define_cast zext
  define_cast sext
  define_cast trunc
  define_cast fpext
  define_cast fptrunc
  define_cast fp2si
  define_cast fp2ui
  define_cast si2fp
  define_cast ui2fp
  define_cast int2ptr
  define_cast ptr2int

  macro self.define_binary(name)"
    def #{name}(lhs, rhs, name = \"\")
      LibLLVM.build_#{name}(@builder, lhs, rhs, name)
    end
  "end

  define_binary add
  define_binary sub
  define_binary mul
  define_binary sdiv
  define_binary exact_sdiv
  define_binary udiv
  define_binary srem
  define_binary urem
  define_binary shl
  define_binary ashr
  define_binary lshr
  define_binary or
  define_binary and
  define_binary xor
  define_binary fadd
  define_binary fsub
  define_binary fmul
  define_binary fdiv

  macro self.define_cmp(name)"
    def #{name}(op, lhs, rhs, name = \"\")
      LibLLVM.build_#{name}(@builder, op, lhs, rhs, name)
    end
  "end

  define_cmp icmp
  define_cmp fcmp

  def not(value, name = "")
    LibLLVM.build_not(@builder, value, name)
  end

  def unreachable
    LibLLVM.build_unreachable(@builder)
  end

  def select(cond, a_then, a_else, name = "")
    LibLLVM.build_select @builder, cond, a_then, a_else, name
  end

  def global_string_pointer(string, name = "")
    LibLLVM.build_global_string_ptr @builder, string, name
  end

  def landing_pad(type, personality, clauses, name = "")
    lpad = LibLLVM.build_landing_pad @builder, type, personality, clauses.length.to_u32, name
    LibLLVM.set_cleanup lpad, 1
    clauses.each do |clause|
      LibLLVM.add_clause lpad, clause
    end
    lpad
  end

  def invoke(fn : Function, args, a_then, a_catch, name = "")
    invoke fn.llvm_function, args, a_then, a_catch, name
  end

  def invoke(fn : LibLLVM::ValueRef, args, a_then, a_catch, name = "")
    LibLLVM.build_invoke @builder, fn, args.buffer, args.length.to_u32, a_then, a_catch, name
  end
end

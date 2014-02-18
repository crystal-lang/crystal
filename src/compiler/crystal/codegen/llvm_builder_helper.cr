module Crystal
  module LLVMBuilderHelper
    def int1(n)
      LLVM.int LLVM::Int1, n
    end

    def int8(n)
      LLVM.int LLVM::Int8, n
    end

    def int16(n)
      LLVM.int LLVM::Int16, n
    end

    def int32(n)
      LLVM.int LLVM::Int32, n
    end

    def int64(n)
      LLVM.int LLVM::Int64, n
    end

    def int(n)
      int32(n)
    end

    def null
      int(0)
    end

    def llvm_nil
      int1(0)
    end

    def llvm_false
      int1(0)
    end

    def llvm_true
      int1(1)
    end

    def equal?(value1, value2)
      builder.icmp LibLLVM::IntPredicate::EQ, value1, value2
    end

    def not_equal?(value1, value2)
      builder.icmp LibLLVM::IntPredicate::NE, value1, value2
    end

    def null_pointer?(value)
      equal? builder.ptr2int(value, LLVM::Int32), null
    end

    def not_null_pointer?(value)
      not_equal? builder.ptr2int(value, LLVM::Int32), null
    end

    def gep(ptr, index0 : Int32)
      gep ptr, int32(index0)
    end

    def gep(ptr, index0 : LibLLVM::ValueRef)
      builder.gep ptr, [index0]
    end

    def gep(ptr, index0 : Int32, index1 : Int32)
      gep ptr, int32(index0), int32(index1)
    end

    def gep(ptr, index0 : LibLLVM::ValueRef, index1 : LibLLVM::ValueRef)
      builder.gep ptr, [index0, index1]
    end

    def ptr2int(value, type)
      builder.ptr2int value, type
    end

    def int2ptr(value, type)
      builder.int2ptr value, type
    end

    def and(value1, value2)
      @builder.and value1, value2
    end

    def or(value1, value2)
      @builder.or value1, value2
    end

    def not(value)
      @builder.not value
    end

    def call(func, args)
      @builder.call func, args
    end

    def bit_cast(value, type)
      builder.bit_cast value, type
    end

    def trunc(value, type)
      builder.trunc value, type
    end

    def load(value)
      builder.load value
    end

    def store(value, ptr)
      builder.store value, ptr
    end

    def br(block)
      builder.br block
    end

    def insert_block
      builder.insert_block
    end

    def position_at_end(block)
      builder.position_at_end block
    end

    def unreachable
      builder.unreachable
    end

    def cond(cond, then_block, else_block)
      builder.cond cond, then_block, else_block
    end

    def phi(type, table)
      builder.phi type, table
    end

    def ret
      builder.ret
    end

    def ret(value)
      builder.ret value
    end

    def pointer_type(type)
      LLVM.pointer_type(type)
    end

    def size_of(type)
      LLVM.size_of type
    end

    def type_of(value)
      LLVM.type_of value
    end
  end
end

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
      builder.icmp LLVM::IntPredicate::EQ, value1, value2
    end

    def not_equal?(value1, value2)
      builder.icmp LLVM::IntPredicate::NE, value1, value2
    end

    def null_pointer?(value)
      equal? builder.ptr2int(value, LLVM::Int32), null
    end

    def not_null_pointer?(value)
      not_equal? builder.ptr2int(value, LLVM::Int32), null
    end

    def gep(ptr, index0 : Int32, name = "")
      gep ptr, int32(index0), name
    end

    def gep(ptr, index0 : LLVM::Value, name = "")
      builder.inbounds_gep ptr, index0, name
    end

    def gep(ptr, index0 : Int32, index1 : Int32, name = "")
      gep ptr, int32(index0), int32(index1), name
    end

    def gep(ptr, index0 : LLVM::Value, index1 : LLVM::Value, name = "")
      builder.inbounds_gep ptr, index0, index1, name
    end

    delegate ptr2int, builder
    delegate int2ptr, builder
    delegate and, builder
    delegate or, builder
    delegate not, builder
    delegate call, builder
    delegate bit_cast, builder
    delegate trunc, builder
    delegate load, builder
    delegate store, builder
    delegate br, builder
    delegate insert_block, builder
    delegate position_at_end, builder
    delegate unreachable, builder
    delegate cond, builder
    delegate phi, builder
    delegate extract_value, builder

    def ret
      builder.ret
    end

    def ret(value : Nil)
      ret
    end

    def ret(value)
      builder.ret value
    end

    def cast_to_void_pointer(pointer)
      bit_cast pointer, LLVM::VoidPointer
    end

    def extend_int(from_type, to_type, value)
      from_type.signed? ? builder.sext(value, llvm_type(to_type)) : builder.zext(value, llvm_type(to_type))
    end

    def extend_float(to_type, value)
      builder.fpext value, llvm_type(to_type)
    end

    def trunc_float(to_type, value)
      builder.fptrunc value, llvm_type(to_type)
    end

    def int_to_float(from_type, to_type, value)
      if from_type.signed?
        builder.si2fp value, llvm_type(to_type)
      else
        builder.ui2fp value, llvm_type(to_type)
      end
    end

    def float_to_int(from_type, to_type, value)
      if to_type.signed?
        builder.fp2si value, llvm_type(to_type)
      else
        builder.fp2ui value, llvm_type(to_type)
      end
    end

    def cast_to(value, type)
      bit_cast value, llvm_type(type)
    end

    def cast_to_pointer(value, type)
      bit_cast value, llvm_type(type).pointer
    end

    delegate llvm_type, llvm_typer
    delegate llvm_struct_type, llvm_typer
    delegate llvm_arg_type, llvm_typer
    delegate llvm_embedded_type, llvm_typer
    delegate llvm_c_type, llvm_typer
    delegate llvm_c_return_type, llvm_typer

    def llvm_fun_type(type)
      llvm_typer.fun_type(type as FunInstanceType)
    end

    def llvm_closure_type(type)
      llvm_typer.closure_type(type as FunInstanceType)
    end

    def llvm_size(type)
      llvm_type(type).size
    end

    def llvm_struct_size(type)
      llvm_struct_type(type).size
    end

    def llvm_union_value_type(type)
      llvm_typer.union_value_type(type)
    end
  end
end

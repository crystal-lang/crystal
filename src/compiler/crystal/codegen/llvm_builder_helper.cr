module Crystal
  record LLVMTypedFunction, type : LLVM::Type, func : LLVM::Function

  module LLVMBuilderHelper
    def int1(n)
      llvm_context.int1.const_int(n)
    end

    def int8(n)
      llvm_context.int8.const_int(n)
    end

    def int16(n)
      llvm_context.int16.const_int(n)
    end

    def int32(n)
      llvm_context.int32.const_int(n)
    end

    def int64(n)
      llvm_context.int64.const_int(n)
    end

    def int128(n)
      llvm_context.int128.const_int(n)
    end

    def int(n)
      int32(n)
    end

    def int(n, type)
      llvm_type(type).const_int(n)
    end

    def float32(value)
      llvm_context.float.const_float(value)
    end

    def float64(value)
      llvm_context.double.const_double(value)
    end

    def float(value, type)
      case type.kind
      when .f32?
        float32(value.to_f32)
      when .f64?
        float64(value.to_f64)
      else
        raise "Unsupported float type"
      end
    end

    def llvm_nil
      llvm_typer.nil_value
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
      builder.icmp LLVM::IntPredicate::EQ, value, value.type.null
    end

    def not_null_pointer?(value)
      builder.icmp LLVM::IntPredicate::NE, value, value.type.null
    end

    def gep(ptr : LLVM::Value, index0 : Int32, name = "")
      gep ptr, int32(index0), name
    end

    def gep(ptr : LLVM::Value, index0 : LLVM::Value, name = "")
      builder.inbounds_gep ptr, index0, name
    end

    def gep(ptr : LLVM::Value, index0 : Int32, index1 : Int32, name = "")
      gep ptr, int32(index0), int32(index1), name
    end

    def gep(ptr : LLVM::Value, index0 : LLVM::Value, index1 : LLVM::Value, name = "")
      builder.inbounds_gep ptr, index0, index1, name
    end

    def gep(type : LLVM::Type, ptr : LLVM::Value, index0 : Int32, name = "")
      gep type, ptr, int32(index0), name
    end

    def gep(type : LLVM::Type, ptr : LLVM::Value, index0 : LLVM::Value, name = "")
      builder.inbounds_gep type, ptr, index0, name
    end

    def gep(type : LLVM::Type, ptr : LLVM::Value, index0 : Int32, index1 : Int32, name = "")
      gep type, ptr, int32(index0), int32(index1), name
    end

    def gep(type : LLVM::Type, ptr : LLVM::Value, index0 : LLVM::Value, index1 : LLVM::Value, name = "")
      builder.inbounds_gep type, ptr, index0, index1, name
    end

    def call(func : LLVMTypedFunction, name : String = "")
      call(func, [] of LLVM::Value, name)
    end

    def call(func : LLVMTypedFunction, arg : LLVM::Value, name : String = "")
      call(func, [arg], name)
    end

    def call(func : LLVMTypedFunction, args : Array(LLVM::Value), name : String = "")
      if catch_pad = @catch_pad
        funclet = builder.build_operand_bundle_def("funclet", [catch_pad])
      else
        funclet = LLVM::OperandBundleDef.null
      end

      builder.call(func.type, func.func, args, bundle: funclet, name: name)
    end

    def invoke(func : LLVMTypedFunction, args : Array(LLVM::Value), a_then, a_catch, name : String = "")
      if catch_pad = @catch_pad
        funclet = builder.build_operand_bundle_def("funclet", [catch_pad])
      else
        funclet = LLVM::OperandBundleDef.null
      end

      builder.invoke(func.type, func.func, args, a_then, a_catch, bundle: funclet, name: name)
    end

    delegate ptr2int, int2ptr, and, or, not, bit_cast,
      trunc, load, store, load_volatile, store_volatile, br, insert_block, position_at_end,
      cond, phi, extract_value, switch, to: builder

    def ret
      builder.ret
    end

    def ret(value : Nil)
      ret
    end

    def ret(value)
      builder.ret value
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

    def cast_to(value : LLVM::ValueMethods, type : Type)
      pointer_cast value, llvm_type(type)
    end

    def cast_to_pointer(value : LLVM::ValueMethods, type : Type)
      pointer_cast value, llvm_type(type).pointer
    end

    def cast_to_void_pointer(pointer : LLVM::ValueMethods)
      pointer_cast pointer, llvm_context.void_pointer
    end

    # *type* must be a pointer type; on LLVM 15.0 or above *type* is not
    # evaluated at all and *value* is returned unchanged, because all opaque
    # pointer types (in the same context) are identical
    macro pointer_cast(value, type)
      {% if LibLLVM::IS_LT_150 %}
        bit_cast({{ value }}, {{ type }})
      {% else %}
        {{ value }}
      {% end %}
    end

    delegate llvm_type, llvm_struct_type, llvm_arg_type, llvm_embedded_type,
      llvm_c_type, llvm_c_return_type, llvm_return_type, llvm_embedded_c_type,
      llvm_intrinsic_return_type, to: llvm_typer

    def llvm_proc_type(type)
      llvm_typer.proc_type(type.as(ProcInstanceType))
    end

    def llvm_closure_type(type)
      llvm_typer.closure_type(type.as(ProcInstanceType))
    end

    def llvm_size(type)
      llvm_type(type).size
    end

    def llvm_struct_size(type)
      llvm_struct_type(type).size
    end
  end
end

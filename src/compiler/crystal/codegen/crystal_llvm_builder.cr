module Crystal
  class CrystalLLVMBuilder
    property end : Bool

    def initialize(@builder : LLVM::Builder, @llvm_typer : LLVMTyper, @printf : LLVMTypedFunction)
      @end = false
    end

    def llvm_nil
      @llvm_typer.nil_value
    end

    def ret
      return llvm_nil if @end
      value = @builder.ret
      @end = true
      value
    end

    def ret(value)
      return llvm_nil if @end
      value = @builder.ret(value)
      @end = true
      value
    end

    def br(block)
      return llvm_nil if @end
      value = @builder.br(block)
      @end = true
      value
    end

    def unreachable
      return if @end
      value = @builder.unreachable
      @end = true
      value
    end

    def printf(format, args = [] of LLVM::Value, catch_pad = nil)
      if catch_pad
        funclet = build_operand_bundle_def("funclet", [catch_pad])
      else
        funclet = LLVM::OperandBundleDef.null
      end

      begin
        call @printf, [global_string_pointer(format)] + args, bundle: funclet
      ensure
        funclet.dispose
      end
    end

    def position_at_end(block)
      @builder.position_at_end block
      @end = false
    end

    def insert_block
      @builder.insert_block
    end

    def build_operand_bundle_def(name, values : Array(LLVM::Value))
      @builder.build_operand_bundle_def(name, values)
    end

    def current_debug_location_metadata
      {% if LibLLVM::IS_LT_90 %}
        LibLLVM.value_as_metadata LibLLVM.get_current_debug_location(@builder)
      {% else %}
        LibLLVM.get_current_debug_location2(@builder)
      {% end %}
    end

    def to_unsafe
      @builder.to_unsafe
    end

    {% for name in %w(add add_handler alloca and ashr atomicrmw bit_cast build_catch_ret call
                     catch_pad catch_switch clear_current_debug_location cmpxchg cond
                     current_debug_location exact_sdiv extract_value fadd fcmp fdiv fence fmul
                     fp2si fp2ui fpext fptrunc fsub global_string_pointer icmp inbounds_gep int2ptr
                     invoke landing_pad load lshr mul not or phi ptr2int sdiv select
                     set_current_debug_location sext shl si2fp srem store store_volatile sub switch
                     trunc udiv ui2fp urem va_arg xor zext) %}
      def {{ name.id }}(*args, **kwargs)
        return llvm_nil if @end

        @builder.{{ name.id }}(*args, **kwargs)
      end
    {% end %}
  end
end

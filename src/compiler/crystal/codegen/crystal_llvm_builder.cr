module Crystal
  class CrystalLLVMBuilder
    getter :end

    def initialize(@builder, @printf)
      @end = false
    end

    def llvm_nil
      LLVM.int LLVM::Int1, 0
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
      if ENV["UNREACHABLE"]? == "1"
        printf "Reached the unreachable!"
      end
      return if @end
      value = @builder.unreachable
      @end = true
      value
    end

    def printf(format, args = [] of LibLLVM::ValueRef)
      call @printf, [global_string_pointer(format)] + args
    end

    def position_at_end(block)
      @builder.position_at_end block
      @end = false
    end

    def insert_block
      @builder.insert_block
    end

    macro method_missing(name, args, block)
      return llvm_nil if @end

      @builder.{{name.id}}({{args.argify}}) {{block}}
    end
  end
end

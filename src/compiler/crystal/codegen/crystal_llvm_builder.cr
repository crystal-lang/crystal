module Crystal
  class CrystalLLVMBuilder
    property end : Bool

    @builder : LLVM::Builder
    @printf : LLVM::Function

    def initialize(@builder, @printf)
      @end = false
    end

    def llvm_nil
      LLVMTyper::NIL_VALUE
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

    def printf(format, args = [] of LLVM::Value)
      call @printf, [global_string_pointer(format)] + args
    end

    def position_at_end(block)
      @builder.position_at_end block
      @end = false
    end

    def insert_block
      @builder.insert_block
    end

    def to_unsafe
      @builder.to_unsafe
    end

    macro method_missing(name, args, block)
      return llvm_nil if @end

      @builder.{{name.id}}({{*args}}) {{block}}
    end
  end
end

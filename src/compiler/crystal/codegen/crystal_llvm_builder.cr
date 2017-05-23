module Crystal
  class CrystalLLVMBuilder
    property end : Bool

    def initialize(@builder : LLVM::Builder, @llvm_typer : LLVMTyper, @printf : LLVM::Function)
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

    macro method_missing(call)
      return llvm_nil if @end

      @builder.{{call}}
    end
  end
end

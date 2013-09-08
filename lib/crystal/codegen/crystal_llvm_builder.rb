module Crystal
  class CrystalLLVMBuilder
    def initialize(builder, llvm_builder, codegen)
      @builder = builder
      @llvm_builder = llvm_builder
      @codegen = codegen
    end

    def landingpad(type, personality, clauses, name = "")
      lpad = LLVM::C.build_landing_pad @llvm_builder, type, personality, clauses.length, name
      LLVM::C.set_cleanup lpad, 1
      clauses.each do |clause|
        LLVM::C.add_clause lpad, clause
      end
      lpad
    end

    def resume(ex)
      LLVM::C.build_resume @llvm_builder, ex
    end

    def ret(*args)
      return if @end
      @builder.ret *args
      @end = true
    end

    def br(*args)
      return if @end
      @builder.br *args
      @end = true
    end

    def unreachable(data = nil)
      if ENV["UNREACHABLE"] == "1"
        backtrace = caller.join("\n")
        msg = "Reached the unreachable!"
        msg << " (#{data})" if data
        msg << "\n#{backtrace}"
        @codegen.llvm_puts(msg)
      end
      return if @end
      @builder.unreachable
      @end = true
    end

    def position_at_end(block)
      @builder.position_at_end block
      @end = false
    end

    def insert_block(*args)
      @builder.insert_block *args
    end

    def method_missing(name, *args)
      return if @end
      @builder.send name, *args
    end
  end
end

# Call convention enum for the Crystal compiler.
#
# This is the compiler's own representation of calling conventions,
# independent of LLVM. The codegen phase maps these to LLVM values.

module Crystal
  enum CallConvention
    C            =  0
    Fast         =  8
    Cold         =  9
    WebKit_JS    = 12
    AnyReg       = 13
    X86_StdCall  = 64
    X86_FastCall = 65

    def to_llvm : LLVM::CallConvention
      LLVM::CallConvention.new(self.value)
    end
  end
end

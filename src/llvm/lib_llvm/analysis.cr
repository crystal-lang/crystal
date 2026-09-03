require "./types"

lib LibLLVM
  fun verify_module = LLVMVerifyModule(m : ModuleRef, action : LLVM::VerifierFailureAction, out_message : Char**) : Bool
end

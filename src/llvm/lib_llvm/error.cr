lib LibLLVM
  type ErrorRef = Void*

  fun get_error_message = LLVMGetErrorMessage(err : ErrorRef) : Char*
  fun dispose_error_message = LLVMDisposeErrorMessage(err_msg : Char*)
end

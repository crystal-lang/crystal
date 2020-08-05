lib LibC
  # based on https://github.com/llvm/llvm-project/blob/bf1cdc2c6c0460b7121ac653c796ef4995b1dfa9/clang/lib/AST/ASTContext.cpp#L7678-L7739
  struct VaList
    __stack : Void*
    __gr_top : Void*
    __vr_top : Void*
    __gr_offs : Int32
    __vr_offs : Int32
  end
end

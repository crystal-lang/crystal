
# Standard C Library Intrinsics
#
# See http://llvm.org/docs/LangRef.html#standard-c-library-intrinsics
module Intrinsics::StdCLib

  lib Lib

    # http://llvm.org/docs/LangRef.html#llvm-memcpy-intrinsic
    # http://llvm.org/docs/LangRef.html#llvm-memmove-intrinsic
    # http://llvm.org/docs/LangRef.html#llvm-memset-intrinsics
    ifdef x86_64
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)
      fun memset = "llvm.memset.p0i8.i64"(dest : Void*, val : UInt8, len : UInt64, align : UInt32, is_volatile : Bool)
    else
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
      fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, align : UInt32, is_volatile : Bool)
    end

  end

  @[AlwaysInline]
  def memcpy(dest, src, len, align, is_volatile)
    Lib.memcpy(dest, src, len, align, is_volatile)
  end

  @[AlwaysInline]
  def memmove(dest, src, len, align, is_volatile)
    Lib.memmove(dest, src, len, align, is_volatile)
  end

  @[AlwaysInline]
  def memset(dest, src, len, align, is_volatile)
    Lib.memset(dest, src, len, align, is_volatile)
  end

end

lib Intrinsics
  alias SizeT = LibC::SizeT

  fun debugtrap = "llvm.debugtrap"
  fun read_cycle_counter = "llvm.readcyclecounter" : UInt64
  fun bswap32 = "llvm.bswap.i32"(id : UInt32) : UInt32

  fun popcount8 = "llvm.ctpop.i8"(src : Int8) : Int8
  fun popcount16 = "llvm.ctpop.i16"(src : Int16) : Int16
  fun popcount32 = "llvm.ctpop.i32"(src : Int32) : Int32
  fun popcount64 = "llvm.ctpop.i64"(src : Int64) : Int64

  fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : SizeT, align : UInt32, is_volatile : Bool)
  fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : SizeT, align : UInt32, is_volatile : Bool)
  fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : SizeT, align : UInt32, is_volatile : Bool)
end

macro debugger
  Intrinsics.debugtrap
end

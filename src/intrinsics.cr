@[Link("m")] ifdef linux
lib Intrinsics
  fun debugtrap = "llvm.debugtrap"
  fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
  fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
  fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, align : UInt32, is_volatile : Bool)
  fun read_cycle_counter = "llvm.readcyclecounter"() : UInt64
end

macro debugger
  Intrinsics.debugtrap
end

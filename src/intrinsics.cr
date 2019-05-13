lib Intrinsics
  fun debugtrap = "llvm.debugtrap"
  {% if flag?(:x86_64) %}
    fun memcpy = "llvm.memcpy.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)
    fun memmove = "llvm.memmove.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)
    fun memset = "llvm.memset.p0i8.i64"(dest : Void*, val : UInt8, len : UInt64, align : UInt32, is_volatile : Bool)
  {% else %}
    fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
    fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
    fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, align : UInt32, is_volatile : Bool)
  {% end %}
  fun read_cycle_counter = "llvm.readcyclecounter" : UInt64
  fun bswap32 = "llvm.bswap.i32"(id : UInt32) : UInt32

  fun popcount8 = "llvm.ctpop.i8"(src : Int8) : Int8
  fun popcount16 = "llvm.ctpop.i16"(src : Int16) : Int16
  fun popcount32 = "llvm.ctpop.i32"(src : Int32) : Int32
  fun popcount64 = "llvm.ctpop.i64"(src : Int64) : Int64
  fun popcount128 = "llvm.ctpop.i128"(src : Int128) : Int128

  fun countleading8 = "llvm.ctlz.i8"(src : Int8, zero_is_undef : Bool) : Int8
  fun countleading16 = "llvm.ctlz.i16"(src : Int16, zero_is_undef : Bool) : Int16
  fun countleading32 = "llvm.ctlz.i32"(src : Int32, zero_is_undef : Bool) : Int32
  fun countleading64 = "llvm.ctlz.i64"(src : Int64, zero_is_undef : Bool) : Int64
  fun countleading128 = "llvm.ctlz.i128"(src : Int128, zero_is_undef : Bool) : Int128

  fun counttrailing8 = "llvm.cttz.i8"(src : Int8, zero_is_undef : Bool) : Int8
  fun counttrailing16 = "llvm.cttz.i16"(src : Int16, zero_is_undef : Bool) : Int16
  fun counttrailing32 = "llvm.cttz.i32"(src : Int32, zero_is_undef : Bool) : Int32
  fun counttrailing64 = "llvm.cttz.i64"(src : Int64, zero_is_undef : Bool) : Int64
  fun counttrailing128 = "llvm.cttz.i128"(src : Int128, zero_is_undef : Bool) : Int128

  fun va_start = "llvm.va_start"(ap : Void*)
  fun va_end = "llvm.va_end"(ap : Void*)
end

macro debugger
  Intrinsics.debugtrap
end

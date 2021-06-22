# Intrinsics as exported by LLVM.
# Use `Intrinsics` to have a unified API across LLVM versions.
lib LibIntrinsics
  fun debugtrap = "llvm.debugtrap"
  {% if flag?(:bits64) %}
    {% if compare_versions(Crystal::LLVM_VERSION, "7.0.0") < 0 %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)
      fun memset = "llvm.memset.p0i8.i64"(dest : Void*, val : UInt8, len : UInt64, align : UInt32, is_volatile : Bool)
    {% else %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)
      fun memset = "llvm.memset.p0i8.i64"(dest : Void*, val : UInt8, len : UInt64, is_volatile : Bool)
    {% end %}
  {% else %}
    {% if compare_versions(Crystal::LLVM_VERSION, "7.0.0") < 0 %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)
      fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, align : UInt32, is_volatile : Bool)
    {% else %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)
      fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, is_volatile : Bool)
    {% end %}
  {% end %}

  fun read_cycle_counter = "llvm.readcyclecounter" : UInt64
  fun bswap32 = "llvm.bswap.i32"(id : UInt32) : UInt32
  fun bswap16 = "llvm.bswap.i16"(id : UInt16) : UInt16

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

  {% if flag?(:i386) || flag?(:x86_64) %}
    fun pause = "llvm.x86.sse2.pause"
  {% end %}
end

module Intrinsics
  def self.debugtrap
    LibIntrinsics.debugtrap
  end

  def self.pause
    {% if flag?(:i386) || flag?(:x86_64) %}
      LibIntrinsics.pause
    {% end %}
  end

  macro memcpy(dest, src, len, is_volatile)
    {% if compare_versions(Crystal::LLVM_VERSION, "7.0.0") < 0 %}
      LibIntrinsics.memcpy({{dest}}, {{src}}, {{len}}, 0, {{is_volatile}})
    {% else %}
      LibIntrinsics.memcpy({{dest}}, {{src}}, {{len}}, {{is_volatile}})
    {% end %}
  end

  macro memmove(dest, src, len, is_volatile)
    {% if compare_versions(Crystal::LLVM_VERSION, "7.0.0") < 0 %}
      LibIntrinsics.memmove({{dest}}, {{src}}, {{len}}, 0, {{is_volatile}})
    {% else %}
      LibIntrinsics.memmove({{dest}}, {{src}}, {{len}}, {{is_volatile}})
    {% end %}
  end

  macro memset(dest, val, len, is_volatile)
    {% if compare_versions(Crystal::LLVM_VERSION, "7.0.0") < 0 %}
      LibIntrinsics.memset({{dest}}, {{val}}, {{len}}, 0, {{is_volatile}})
    {% else %}
      LibIntrinsics.memset({{dest}}, {{val}}, {{len}}, {{is_volatile}})
    {% end %}
  end

  def self.read_cycle_counter
    LibIntrinsics.read_cycle_counter
  end

  def self.bswap32(id) : UInt32
    LibIntrinsics.bswap32(id)
  end

  def self.bswap16(id)
    LibIntrinsics.bswap16(id)
  end

  def self.popcount8(src) : Int8
    LibIntrinsics.popcount8(src)
  end

  def self.popcount16(src) : Int16
    LibIntrinsics.popcount16(src)
  end

  def self.popcount32(src) : Int32
    LibIntrinsics.popcount32(src)
  end

  def self.popcount64(src) : Int64
    LibIntrinsics.popcount64(src)
  end

  def self.popcount128(src)
    LibIntrinsics.popcount128(src)
  end

  macro countleading8(src, zero_is_undef)
    LibIntrinsics.countleading8({{src}}, {{zero_is_undef}})
  end

  macro countleading16(src, zero_is_undef)
    LibIntrinsics.countleading16({{src}}, {{zero_is_undef}})
  end

  macro countleading32(src, zero_is_undef)
    LibIntrinsics.countleading32({{src}}, {{zero_is_undef}})
  end

  macro countleading64(src, zero_is_undef)
    LibIntrinsics.countleading64({{src}}, {{zero_is_undef}})
  end

  macro countleading128(src, zero_is_undef)
    LibIntrinsics.countleading128({{src}}, {{zero_is_undef}})
  end

  macro counttrailing8(src, zero_is_undef)
    LibIntrinsics.counttrailing8({{src}}, {{zero_is_undef}})
  end

  macro counttrailing16(src, zero_is_undef)
    LibIntrinsics.counttrailing16({{src}}, {{zero_is_undef}})
  end

  macro counttrailing32(src, zero_is_undef)
    LibIntrinsics.counttrailing32({{src}}, {{zero_is_undef}})
  end

  macro counttrailing64(src, zero_is_undef)
    LibIntrinsics.counttrailing64({{src}}, {{zero_is_undef}})
  end

  macro counttrailing128(src, zero_is_undef)
    LibIntrinsics.counttrailing128({{src}}, {{zero_is_undef}})
  end

  macro va_start(ap)
    LibIntrinsics.va_start({{ap}})
  end

  macro va_end(ap)
    LibIntrinsics.va_end({{ap}})
  end
end

macro debugger
  Intrinsics.debugtrap
end

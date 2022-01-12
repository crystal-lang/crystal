# Intrinsics as exported by LLVM.
# Use `Intrinsics` to have a unified API across LLVM versions.
lib LibIntrinsics
  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_debugtrap)] {% end %}
  fun debugtrap = "llvm.debugtrap"

  {% if flag?(:bits64) %}
    {% if compare_versions(Crystal::LLVM_VERSION, "7.0.0") < 0 %}
      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
      fun memmove = "llvm.memmove.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, align : UInt32, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
      fun memset = "llvm.memset.p0i8.i64"(dest : Void*, val : UInt8, len : UInt64, align : UInt32, is_volatile : Bool)
    {% else %}
      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
      fun memmove = "llvm.memmove.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
      fun memset = "llvm.memset.p0i8.i64"(dest : Void*, val : UInt8, len : UInt64, is_volatile : Bool)
    {% end %}
  {% else %}
    {% if compare_versions(Crystal::LLVM_VERSION, "7.0.0") < 0 %}
      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
      fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, align : UInt32, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
      fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, align : UInt32, is_volatile : Bool)
    {% else %}
      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
      fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)

      {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
      fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, is_volatile : Bool)
    {% end %}
  {% end %}

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_read_cycle_counter)] {% end %}
  fun read_cycle_counter = "llvm.readcyclecounter" : UInt64

  fun bitreverse64 = "llvm.bitreverse.i64"(id : UInt64) : UInt64
  fun bitreverse32 = "llvm.bitreverse.i32"(id : UInt32) : UInt32
  fun bitreverse16 = "llvm.bitreverse.i16"(id : UInt16) : UInt16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bswap32)] {% end %}
  fun bswap32 = "llvm.bswap.i32"(id : UInt32) : UInt32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bswap16)] {% end %}
  fun bswap16 = "llvm.bswap.i16"(id : UInt16) : UInt16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount8)] {% end %}
  fun popcount8 = "llvm.ctpop.i8"(src : Int8) : Int8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount16)] {% end %}
  fun popcount16 = "llvm.ctpop.i16"(src : Int16) : Int16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount32)] {% end %}
  fun popcount32 = "llvm.ctpop.i32"(src : Int32) : Int32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount64)] {% end %}
  fun popcount64 = "llvm.ctpop.i64"(src : Int64) : Int64

  fun popcount128 = "llvm.ctpop.i128"(src : Int128) : Int128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading8)] {% end %}
  fun countleading8 = "llvm.ctlz.i8"(src : Int8, zero_is_undef : Bool) : Int8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading16)] {% end %}
  fun countleading16 = "llvm.ctlz.i16"(src : Int16, zero_is_undef : Bool) : Int16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading32)] {% end %}
  fun countleading32 = "llvm.ctlz.i32"(src : Int32, zero_is_undef : Bool) : Int32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading64)] {% end %}
  fun countleading64 = "llvm.ctlz.i64"(src : Int64, zero_is_undef : Bool) : Int64

  fun countleading128 = "llvm.ctlz.i128"(src : Int128, zero_is_undef : Bool) : Int128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing8)] {% end %}
  fun counttrailing8 = "llvm.cttz.i8"(src : Int8, zero_is_undef : Bool) : Int8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing16)] {% end %}
  fun counttrailing16 = "llvm.cttz.i16"(src : Int16, zero_is_undef : Bool) : Int16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing32)] {% end %}
  fun counttrailing32 = "llvm.cttz.i32"(src : Int32, zero_is_undef : Bool) : Int32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing64)] {% end %}
  fun counttrailing64 = "llvm.cttz.i64"(src : Int64, zero_is_undef : Bool) : Int64
  fun counttrailing128 = "llvm.cttz.i128"(src : Int128, zero_is_undef : Bool) : Int128

  fun va_start = "llvm.va_start"(ap : Void*)
  fun va_end = "llvm.va_end"(ap : Void*)

  {% if flag?(:i386) || flag?(:x86_64) %}
    {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_pause)] {% end %}
    fun pause = "llvm.x86.sse2.pause"
  {% end %}

  {% if flag?(:arm) %}
    {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_pause)] {% end %}
    fun arm_hint = "llvm.arm.hint"(hint : ARMHint)
  {% elsif flag?(:aarch64) %}
    {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_pause)] {% end %}
    fun arm_hint = "llvm.aarch64.hint"(hint : ARMHint)
  {% end %}
end

module Intrinsics
  macro debugtrap
    LibIntrinsics.debugtrap
  end

  def self.pause
    {% if flag?(:i386) || flag?(:x86_64) %}
      LibIntrinsics.pause
    {% elsif flag?(:arm) || flag?(:aarch64) %}
      LibIntrinsics.arm_hint(1) # YIELD
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

  def self.bitreverse64(id) : UInt64
    LibIntrinsics.bitreverse64(id)
  end

  def self.bitreverse32(id) : UInt32
    LibIntrinsics.bitreverse32(id)
  end

  def self.bitreverse16(id) : UInt16
    LibIntrinsics.bitreverse16(id)
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

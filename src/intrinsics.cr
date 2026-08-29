# Intrinsics as exported by LLVM.
# Use `Intrinsics` to have a unified API across LLVM versions.
lib LibIntrinsics
  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_debugtrap)] {% end %}
  fun debugtrap = "llvm.debugtrap"

  {% if flag?(:avr) %}
    {% if compare_versions(Crystal::LLVM_VERSION, "15.0.0") < 0 %}
      fun memcpy = "llvm.memcpy.p0i8.p0i8.i16"(dest : Void*, src : Void*, len : UInt16, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0i8.p0i8.i16"(dest : Void*, src : Void*, len : UInt16, is_volatile : Bool)
      fun memset = "llvm.memset.p0i8.i16"(dest : Void*, val : UInt8, len : UInt16, is_volatile : Bool)
    {% else %}
      fun memcpy = "llvm.memcpy.p0.p0.i16"(dest : Void*, src : Void*, len : UInt16, is_volatile : Bool)
      fun memmove = "llvm.memmove.p0.p0.i16"(dest : Void*, src : Void*, len : UInt16, is_volatile : Bool)
      fun memset = "llvm.memset.p0.i16"(dest : Void*, val : UInt8, len : UInt16, is_volatile : Bool)
    {% end %}
  {% else %}
    {% if flag?(:bits64) %}
      {% if compare_versions(Crystal::LLVM_VERSION, "15.0.0") < 0 %}
        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
        fun memcpy = "llvm.memcpy.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
        fun memmove = "llvm.memmove.p0i8.p0i8.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
        fun memset = "llvm.memset.p0i8.i64"(dest : Void*, val : UInt8, len : UInt64, is_volatile : Bool)
      {% else %}
        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
        fun memcpy = "llvm.memcpy.p0.p0.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
        fun memmove = "llvm.memmove.p0.p0.i64"(dest : Void*, src : Void*, len : UInt64, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
        fun memset = "llvm.memset.p0.i64"(dest : Void*, val : UInt8, len : UInt64, is_volatile : Bool)
      {% end %}
    {% else %}
      {% if compare_versions(Crystal::LLVM_VERSION, "15.0.0") < 0 %}
        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
        fun memcpy = "llvm.memcpy.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
        fun memmove = "llvm.memmove.p0i8.p0i8.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
        fun memset = "llvm.memset.p0i8.i32"(dest : Void*, val : UInt8, len : UInt32, is_volatile : Bool)
      {% else %}
        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memcpy)] {% end %}
        fun memcpy = "llvm.memcpy.p0.p0.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memmove)] {% end %}
        fun memmove = "llvm.memmove.p0.p0.i32"(dest : Void*, src : Void*, len : UInt32, is_volatile : Bool)

        {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_memset)] {% end %}
        fun memset = "llvm.memset.p0.i32"(dest : Void*, val : UInt8, len : UInt32, is_volatile : Bool)
      {% end %}
    {% end %}
  {% end %}

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_read_cycle_counter)] {% end %}
  fun read_cycle_counter = "llvm.readcyclecounter" : UInt64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bitreverse8)] {% end %}
  fun bitreverse8 = "llvm.bitreverse.i8"(id : UInt8) : UInt8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bitreverse16)] {% end %}
  fun bitreverse16 = "llvm.bitreverse.i16"(id : UInt16) : UInt16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bitreverse32)] {% end %}
  fun bitreverse32 = "llvm.bitreverse.i32"(id : UInt32) : UInt32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bitreverse64)] {% end %}
  fun bitreverse64 = "llvm.bitreverse.i64"(id : UInt64) : UInt64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bitreverse128)] {% end %}
  fun bitreverse128 = "llvm.bitreverse.i128"(id : UInt128) : UInt128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bswap16)] {% end %}
  fun bswap16 = "llvm.bswap.i16"(id : UInt16) : UInt16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bswap32)] {% end %}
  fun bswap32 = "llvm.bswap.i32"(id : UInt32) : UInt32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bswap64)] {% end %}
  fun bswap64 = "llvm.bswap.i64"(id : UInt64) : UInt64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_bswap128)] {% end %}
  fun bswap128 = "llvm.bswap.i128"(id : UInt128) : UInt128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount8)] {% end %}
  fun popcount8 = "llvm.ctpop.i8"(src : Int8) : Int8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount16)] {% end %}
  fun popcount16 = "llvm.ctpop.i16"(src : Int16) : Int16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount32)] {% end %}
  fun popcount32 = "llvm.ctpop.i32"(src : Int32) : Int32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount64)] {% end %}
  fun popcount64 = "llvm.ctpop.i64"(src : Int64) : Int64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_popcount128)] {% end %}
  fun popcount128 = "llvm.ctpop.i128"(src : Int128) : Int128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading8)] {% end %}
  fun countleading8 = "llvm.ctlz.i8"(src : Int8, zero_is_undef : Bool) : Int8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading16)] {% end %}
  fun countleading16 = "llvm.ctlz.i16"(src : Int16, zero_is_undef : Bool) : Int16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading32)] {% end %}
  fun countleading32 = "llvm.ctlz.i32"(src : Int32, zero_is_undef : Bool) : Int32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading64)] {% end %}
  fun countleading64 = "llvm.ctlz.i64"(src : Int64, zero_is_undef : Bool) : Int64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_countleading128)] {% end %}
  fun countleading128 = "llvm.ctlz.i128"(src : Int128, zero_is_undef : Bool) : Int128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing8)] {% end %}
  fun counttrailing8 = "llvm.cttz.i8"(src : Int8, zero_is_undef : Bool) : Int8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing16)] {% end %}
  fun counttrailing16 = "llvm.cttz.i16"(src : Int16, zero_is_undef : Bool) : Int16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing32)] {% end %}
  fun counttrailing32 = "llvm.cttz.i32"(src : Int32, zero_is_undef : Bool) : Int32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing64)] {% end %}
  fun counttrailing64 = "llvm.cttz.i64"(src : Int64, zero_is_undef : Bool) : Int64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_counttrailing128)] {% end %}
  fun counttrailing128 = "llvm.cttz.i128"(src : Int128, zero_is_undef : Bool) : Int128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshl8)] {% end %}
  fun fshl8 = "llvm.fshl.i8"(a : UInt8, b : UInt8, count : UInt8) : UInt8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshl16)] {% end %}
  fun fshl16 = "llvm.fshl.i16"(a : UInt16, b : UInt16, count : UInt16) : UInt16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshl32)] {% end %}
  fun fshl32 = "llvm.fshl.i32"(a : UInt32, b : UInt32, count : UInt32) : UInt32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshl64)] {% end %}
  fun fshl64 = "llvm.fshl.i64"(a : UInt64, b : UInt64, count : UInt64) : UInt64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshl128)] {% end %}
  fun fshl128 = "llvm.fshl.i128"(a : UInt128, b : UInt128, count : UInt128) : UInt128

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshr8)] {% end %}
  fun fshr8 = "llvm.fshr.i8"(a : UInt8, b : UInt8, count : UInt8) : UInt8

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshr16)] {% end %}
  fun fshr16 = "llvm.fshr.i16"(a : UInt16, b : UInt16, count : UInt16) : UInt16

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshr32)] {% end %}
  fun fshr32 = "llvm.fshr.i32"(a : UInt32, b : UInt32, count : UInt32) : UInt32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshr64)] {% end %}
  fun fshr64 = "llvm.fshr.i64"(a : UInt64, b : UInt64, count : UInt64) : UInt64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_fshr128)] {% end %}
  fun fshr128 = "llvm.fshr.i128"(a : UInt128, b : UInt128, count : UInt128) : UInt128

  {% if compare_versions(Crystal::LLVM_VERSION, "19.1.0") < 0 %}
    fun va_start = "llvm.va_start"(ap : Void*)
    fun va_end = "llvm.va_end"(ap : Void*)
  {% else %}
    fun va_start = "llvm.va_start.p0"(ap : Void*)
    fun va_end = "llvm.va_end.p0"(ap : Void*)
  {% end %}

  {% if flag?(:i386) || flag?(:x86_64) %}
    {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_pause)] {% end %}
    fun pause = "llvm.x86.sse2.pause"
  {% end %}

  {% if flag?(:aarch64) %}
    {% if flag?(:interpreted) %} @[Primitive(:interpreter_intrinsics_pause)] {% end %}
    fun arm_hint = "llvm.aarch64.hint"(hint : Int32)
  {% end %}
end

module Intrinsics
  macro debugtrap
    ::LibIntrinsics.debugtrap
  end

  def self.pause
    {% if flag?(:i386) || flag?(:x86_64) %}
      LibIntrinsics.pause
    {% elsif flag?(:aarch64) %}
      LibIntrinsics.arm_hint(1) # YIELD
    {% end %}
  end

  macro memcpy(dest, src, len, is_volatile)
    ::LibIntrinsics.memcpy({{ dest }}, {{ src }}, {{ len }}, {{ is_volatile }})
  end

  macro memmove(dest, src, len, is_volatile)
    ::LibIntrinsics.memmove({{ dest }}, {{ src }}, {{ len }}, {{ is_volatile }})
  end

  macro memset(dest, val, len, is_volatile)
    ::LibIntrinsics.memset({{ dest }}, {{ val }}, {{ len }}, {{ is_volatile }})
  end

  def self.read_cycle_counter
    LibIntrinsics.read_cycle_counter
  end

  def self.bitreverse8(id) : UInt8
    LibIntrinsics.bitreverse8(id)
  end

  def self.bitreverse16(id) : UInt16
    LibIntrinsics.bitreverse16(id)
  end

  def self.bitreverse32(id) : UInt32
    LibIntrinsics.bitreverse32(id)
  end

  def self.bitreverse64(id) : UInt64
    LibIntrinsics.bitreverse64(id)
  end

  def self.bitreverse128(id) : UInt128
    LibIntrinsics.bitreverse128(id)
  end

  def self.bswap16(id) : UInt16
    LibIntrinsics.bswap16(id)
  end

  def self.bswap32(id) : UInt32
    LibIntrinsics.bswap32(id)
  end

  def self.bswap64(id) : UInt64
    LibIntrinsics.bswap64(id)
  end

  def self.bswap128(id) : UInt128
    LibIntrinsics.bswap128(id)
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
    ::LibIntrinsics.countleading8({{ src }}, {{ zero_is_undef }})
  end

  macro countleading16(src, zero_is_undef)
    ::LibIntrinsics.countleading16({{ src }}, {{ zero_is_undef }})
  end

  macro countleading32(src, zero_is_undef)
    ::LibIntrinsics.countleading32({{ src }}, {{ zero_is_undef }})
  end

  macro countleading64(src, zero_is_undef)
    ::LibIntrinsics.countleading64({{ src }}, {{ zero_is_undef }})
  end

  macro countleading128(src, zero_is_undef)
    ::LibIntrinsics.countleading128({{ src }}, {{ zero_is_undef }})
  end

  macro counttrailing8(src, zero_is_undef)
    ::LibIntrinsics.counttrailing8({{ src }}, {{ zero_is_undef }})
  end

  macro counttrailing16(src, zero_is_undef)
    ::LibIntrinsics.counttrailing16({{ src }}, {{ zero_is_undef }})
  end

  macro counttrailing32(src, zero_is_undef)
    ::LibIntrinsics.counttrailing32({{ src }}, {{ zero_is_undef }})
  end

  macro counttrailing64(src, zero_is_undef)
    ::LibIntrinsics.counttrailing64({{ src }}, {{ zero_is_undef }})
  end

  macro counttrailing128(src, zero_is_undef)
    ::LibIntrinsics.counttrailing128({{ src }}, {{ zero_is_undef }})
  end

  def self.fshl8(a, b, count) : UInt8
    LibIntrinsics.fshl8(a, b, count)
  end

  def self.fshl16(a, b, count) : UInt16
    LibIntrinsics.fshl16(a, b, count)
  end

  def self.fshl32(a, b, count) : UInt32
    LibIntrinsics.fshl32(a, b, count)
  end

  def self.fshl64(a, b, count) : UInt64
    LibIntrinsics.fshl64(a, b, count)
  end

  def self.fshl128(a, b, count) : UInt128
    LibIntrinsics.fshl128(a, b, count)
  end

  def self.fshr8(a, b, count) : UInt8
    LibIntrinsics.fshr8(a, b, count)
  end

  def self.fshr16(a, b, count) : UInt16
    LibIntrinsics.fshr16(a, b, count)
  end

  def self.fshr32(a, b, count) : UInt32
    LibIntrinsics.fshr32(a, b, count)
  end

  def self.fshr64(a, b, count) : UInt64
    LibIntrinsics.fshr64(a, b, count)
  end

  def self.fshr128(a, b, count) : UInt128
    LibIntrinsics.fshr128(a, b, count)
  end

  macro va_start(ap)
    ::LibIntrinsics.va_start({{ ap }})
  end

  macro va_end(ap)
    ::LibIntrinsics.va_end({{ ap }})
  end

  # Should codegen to the following LLVM IR (before being inlined):
  # ```
  # define internal void @"*Intrinsics::unreachable:NoReturn"() #12 {
  # entry:
  #   unreachable
  # }
  # ```
  #
  # Can be used like `@llvm.assume(i1 cond)` as `unreachable unless (assumption)`.
  #
  # WARNING: the behaviour of the program is undefined if the assumption is broken!
  @[AlwaysInline]
  def self.unreachable : NoReturn
    x = uninitialized NoReturn
    x
  end
end

# Invokes an execution trap to catch the attention of a debugger. This has the
# same effect as placing a breakpoint in debuggers or IDEs supporting them.
#
# Execution is allowed to continue if the debugger instructs so. If no debugger
# is attached, usually the current process terminates with a status that
# corresponds to `Process::ExitReason::Breakpoint`.
#
# Inside an interpreter session, this drops into the REPL's pry mode instead of
# a system debugger.
macro debugger
  ::Intrinsics.debugtrap
end

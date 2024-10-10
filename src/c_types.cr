# This module exposes the various common platform-dependent arithmetic types
# from the C language, to be used in lib bindings.
#
# For convenience, libs can import types from this module using aliases, so that
# the types can be used inside the lib without fully qualified paths:
#
# ```
# lib LibFoo
#   alias Int = CTypes::Int
#
#   fun foo(x : Int) : Int     # okay
#   fun bar(x : CTypes::Char*) # okay
# end
# ```
module CTypes
  {% unless flag?(:bits32) || flag?(:bits64) %}
    {% if target = Crystal.constant("TARGET_TRIPLE") %}
      {% raise "Unsupported target: #{target.id}" %}
    {% else %}
      # this is for old compilers that attempt to directly use a newer stdlib
      # for cross-compilation
      {% raise "Architecture with unsupported word size" %}
    {% end %}
  {% end %}

  # The C `char` type.
  #
  # Guaranteed to have at least 8 bits. Equivalent to `UInt8` on all currently
  # supported targets.
  alias Char = UInt8

  # The C `signed char` type.
  #
  # Guaranteed to have at least 8 bits. Equivalent to `Int8` on all currently
  # supported targets.
  alias SChar = Int8

  # The C `unsigned char` type.
  #
  # Guaranteed to have at least 8 bits. Equivalent to `UInt8` on all currently
  # supported targets.
  alias UChar = UInt8

  # The C `short` type.
  #
  # Guaranteed to have at least 16 bits. Equivalent to `Int16` on all currently
  # supported targets.
  alias Short = Int16

  # The C `unsigned short` type.
  #
  # Guaranteed to have at least 16 bits. Equivalent to `UInt16` on all currently
  # supported targets.
  alias UShort = UInt16

  # The C `int` type.
  #
  # Guaranteed to have at least 16 bits. Equivalent to `Int32` on all currently
  # supported targets.
  alias Int = Int32

  # The C `unsigned int` type.
  #
  # Guaranteed to have at least 16 bits. Equivalent to `UInt32` on all currently
  # supported targets.
  alias UInt = UInt32

  # The C `long` type.
  #
  # Guaranteed to have at least 32 bits. Equivalent to `Int32` on Windows and
  # on 32-bit targets. Equivalent to `Int64` on 64-bit, non-Windows targets.
  {% if flag?(:bits32) || flag?(:win32) %}
    alias Long = Int32
  {% elsif flag?(:bits64) %}
    alias Long = Int64
  {% end %}

  # The C `unsigned long` type.
  #
  # Guaranteed to have at least 32 bits. Equivalent to `UInt32` on Windows and
  # on 32-bit targets. Equivalent to `UInt64` on 64-bit, non-Windows targets.
  {% if flag?(:bits32) || flag?(:win32) %}
    alias ULong = UInt32
  {% elsif flag?(:bits64) %}
    alias ULong = UInt64
  {% end %}

  # The C `long long` type.
  #
  # Guaranteed to have at least 64 bits. Equivalent to `Int64` on all currently
  # supported targets.
  alias LongLong = Int64

  # The C `unsigned long long` type.
  #
  # Guaranteed to have at least 64 bits. Equivalent to `UInt64` on all currently
  # supported targets.
  alias ULongLong = UInt64

  # The C `float` type.
  #
  # Equivalent to `Float32` on all currently supported targets.
  alias Float = Float32

  # The C `double` type.
  #
  # Equivalent to `Float64` on all currently supported targets.
  alias Double = Float64

  # The C `intptr_t` type.
  #
  # Large enough to hold the value of `Pointer#address`. Equivalent to `Int32`
  # on 32-bit targets, `Int64` on 64-bit targets.
  {% if flag?(:bits32) %}
    alias IntPtrT = Int32
  {% elsif flag?(:bits64) %}
    alias IntPtrT = Int64
  {% end %}

  # The C `uintptr_t` type.
  #
  # Large enough to hold the value of `Pointer#address`. Equivalent to `UInt32`
  # on 32-bit targets, `UInt64` on 64-bit targets.
  {% if flag?(:bits32) %}
    alias UIntPtrT = UInt32
  {% elsif flag?(:bits64) %}
    alias UIntPtrT = UInt64
  {% end %}

  # The C `size_t` type.
  #
  # Large enough to hold the value of `sizeof` for any type. Guaranteed to have
  # at least 16 bits. Equivalent to `UInt32` on 32-bit targets, `UInt64` on
  # 64-bit targets.
  {% if flag?(:bits32) %}
    alias SizeT = UInt32
  {% elsif flag?(:bits64) %}
    alias SizeT = UInt64
  {% end %}

  # The C `ptrdiff_t` type.
  #
  # Large enough to hold the value of `Pointer#-(Pointer)`. Guaranteed to have
  # at least 17 bits. Equivalent to `Int32` on 32-bit targets, `Int64` on 64-bit
  # targets.
  {% if flag?(:bits32) %}
    alias PtrDiffT = Int32
  {% elsif flag?(:bits64) %}
    alias PtrDiffT = Int64
  {% end %}
end

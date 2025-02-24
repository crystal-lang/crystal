# Supported library versions:
#
# * libffi
#
# See https://crystal-lang.org/reference/man/required_libraries.html#compiler-dependencies
module Crystal
  @[Link("ffi")]
  {% if compare_versions(Crystal::VERSION, "1.11.0-dev") >= 0 %}
    @[Link(dll: "libffi.dll")]
  {% end %}
  lib LibFFI
    {% begin %}
    enum ABI
      {% if flag?(:x86_64) && flag?(:win32) %}
        WIN64 = 1
        GNUW64

        {% if flag?(:gnu) %}
          DEFAULT = GNUW64
        {% else %}
          DEFAULT = WIN64
        {% end %}
      {% elsif flag?(:x86_64) && flag?(:unix) %}
        UNIX64 = 2
        WIN64
        EFI64 = WIN64
        GNUW64

        DEFAULT = UNIX64
      {% elsif flag?(:i386) && flag?(:win32) %}
        SYSV = 1
        STDCALL
        THISCALL
        FASTCALL
        MS_CDECL
        PASCAL
        REGISTER
        LAST

        DEFAULT = MS_CDECL
      {% elsif flag?(:i386) && flag?(:unix) %}
        SYSV     = 1
        THISCALL = 3
        FASTCALL
        STDCALL
        PASCAL
        REGISTER
        MS_CDECL
        LAST

        DEFAULT = SYSV
      {% elsif flag?(:aarch64) %}
        SYSV = 1
        WIN64
        LAST

        {% if flag?(:win32) %}
          DEFAULT = WIN64
        {% else %}
          DEFAULT = SYSV
        {% end %}
      {% elsif flag?(:arm) %}
        SYSV = 1
        VFP

        {% if flag?(:armhf) || flag?(:win32) %}
          DEFAULT = VFP
        {% else %}
          DEFAULT = SYSV
        {% end %}
      {% else %}
        {% raise "Unsupported target for ABI" %}
      {% end %}
    end
    {% end %}

    enum Status
      OK          = 0
      BAD_TYPEDEF
      BAD_ABI
      BAD_ARGTYPE
    end

    enum TypeEnum : UInt16
      VOID       =  0
      INT        =  1
      FLOAT      =  2
      DOUBLE     =  3
      LONGDOUBLE =  4
      UINT8      =  5
      SINT8      =  6
      UINT16     =  7
      SINT16     =  8
      UINT32     =  9
      SINT32     = 10
      UINT64     = 11
      SINT64     = 12
      STRUCT     = 13
      POINTER    = 14
      COMPLEX    = 15
    end

    struct Cif
      abi : ABI
      nargs : LibC::UInt
      arg_types : Type**
      rtype : Type*
      bytes : LibC::UInt
      flags : LibC::UInt
    end

    struct Type
      size : LibC::SizeT
      alignment : UInt16
      type : TypeEnum
      elements : Type**
    end

    $ffi_type_void : Type
    $ffi_type_uint8 : Type
    $ffi_type_sint8 : Type
    $ffi_type_uint16 : Type
    $ffi_type_sint16 : Type
    $ffi_type_uint32 : Type
    $ffi_type_sint32 : Type
    $ffi_type_uint64 : Type
    $ffi_type_sint64 : Type
    $ffi_type_float : Type
    $ffi_type_double : Type
    $ffi_type_pointer : Type

    # We're treating ffi_closure as an opaque type because we do not need to interact
    # with it directly and only pass a pointer around. We only need to allocate
    # the memory, but the memory size differs based on target and ABI version (https://github.com/libffi/libffi/pull/540)
    # We define the maximum possible size for each target and allocate that amount
    # of memory, even if less would suffice. Overallocating a couple of bytes should
    # not cause any issues
    # https://github.com/crystal-lang/crystal/pull/12192#issuecomment-1173993292
    # https://github.com/libffi/libffi/blob/ddc6764386b29449d941b2b18d000f2987a9d848/doc/libffi.texi#L815
    type Closure = Void

    {% if flag?(:bits64) %}
      SIZEOF_CLOSURE = 56
    {% else %}
      SIZEOF_CLOSURE = 40
    {% end %}

    alias ClosureFun = Cif*, Void*, Void**, Void* -> Void

    fun prep_cif = ffi_prep_cif(
      cif : Cif*,
      abi : ABI,
      nargs : LibC::UInt,
      rtype : Type*,
      atypes : Type**,
    ) : Status

    fun prep_cif_var = ffi_prep_cif_var(
      cif : Cif*,
      abi : ABI,
      nfixedargs : LibC::UInt,
      varntotalargs : LibC::UInt,
      rtype : Type*,
      atypes : Type**,
    ) : Status

    @[Raises]
    fun call = ffi_call(
      cif : Cif*,
      fn : Void*,
      rvalue : Void*,
      avalue : Void**,
    ) : Void

    fun closure_alloc = ffi_closure_alloc(size : LibC::SizeT, code : Void**) : Closure*
    fun closure_free = ffi_closure_free(Void*)
    fun prep_closure_loc = ffi_prep_closure_loc(
      closure : Closure*,
      cif : Cif*,
      fun : ClosureFun,
      user_data : Void*,
      code_loc : Void*,
    ) : Status
  end
end

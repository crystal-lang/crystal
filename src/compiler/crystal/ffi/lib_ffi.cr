module Crystal
  @[Link("ffi")]
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

    # TODO: this is 12 for non-x

    {% if compare_versions(`hash pkg-config 2> /dev/null && pkg-config --modversion libffi`.chomp, "3.4.0") >= 0 %}
      {% if flag?(:bits64) %}
        FFI_TRAMPOLINE_SIZE = 32
      {% else %}
        FFI_TRAMPOLINE_SIZE = 16
      {% end %}
    {% else %}
      {% if flag?(:bits64) %}
        FFI_TRAMPOLINE_SIZE = 24
      {% else %}
        FFI_TRAMPOLINE_SIZE = 12
      {% end %}
    {% end %}

    alias ClosureFun = Cif*, Void*, Void**, Void* -> Void

    struct Closure
      tramp : LibC::Char[FFI_TRAMPOLINE_SIZE]
      cif : Cif*
      fun : ClosureFun
      user_data : Void*
    end

    fun prep_cif = ffi_prep_cif(
      cif : Cif*,
      abi : ABI,
      nargs : LibC::UInt,
      rtype : Type*,
      atypes : Type**
    ) : Status

    fun prep_cif_var = ffi_prep_cif_var(
      cif : Cif*,
      abi : ABI,
      nfixedargs : LibC::UInt,
      varntotalargs : LibC::UInt,
      rtype : Type*,
      atypes : Type**
    ) : Status

    @[Raises]
    fun call = ffi_call(
      cif : Cif*,
      fn : Void*,
      rvalue : Void*,
      avalue : Void**
    ) : Void

    fun closure_alloc = ffi_closure_alloc(size : LibC::SizeT, code : Void**) : Closure*
    fun closure_free = ffi_closure_free(Void*)
    fun prep_closure_loc = ffi_prep_closure_loc(
      closure : Closure*,
      cif : Cif*,
      fun : ClosureFun,
      user_data : Void*,
      code_loc : Void*
    ) : Status
  end
end

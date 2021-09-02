require "./enums"

module Crystal
  @[Link("ffi")]
  lib LibFFI
    struct Cif
      abi : FFI::ABI
      nargs : LibC::UInt
      arg_types : Type**
      rtype : Type*
      bytes : LibC::UInt
      flags : LibC::UInt
    end

    struct Type
      size : LibC::SizeT
      alignment : UInt16
      type : FFI::TypeEnum
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

    {% if flag?(:bits64) %}
      FFI_TRAMPOLINE_SIZE = 24
    {% else %}
      FFI_TRAMPOLINE_SIZE = 12
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
      abi : FFI::ABI,
      nargs : LibC::UInt,
      rtype : Type*,
      atypes : Type**
    ) : FFI::Status

    fun prep_cif_var = ffi_prep_cif_var(
      cif : Cif*,
      abi : FFI::ABI,
      nfixedargs : LibC::UInt,
      varntotalargs : LibC::UInt,
      rtype : Type*,
      atypes : Type**
    ) : FFI::Status

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
    ) : FFI::Status
  end
end

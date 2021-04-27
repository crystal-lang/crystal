require "./enums"

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
    type : UInt16
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

  fun prep_cif = ffi_prep_cif(
    cif : Cif*,
    abi : FFI::ABI,
    nargs : LibC::UInt,
    rtype : Type*,
    atypes : Type**
  ) : FFI::Status

  fun call = ffi_call(
    cif : Cif*,
    fn : Void*,
    rvalue : Void*,
    avalue : Void**
  ) : Void
end

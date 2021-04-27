require "./lib_ffi"
require "./enums"
require "./type"
require "./call_interface"

module FFI
  def self.prepare(abi : FFI::ABI, args : Array(FFI::Type), return_type : FFI::Type) : CallInterface
    cif = LibFFI::Cif.new

    status = LibFFI.prep_cif(
      pointerof(cif),
      abi,
      args.size,
      return_type,
      args.to_unsafe.as(Pointer(LibFFI::Type*)),
    )

    unless status.ok?
      raise "Error preparing FFI call: #{status}"
    end

    CallInterface.new(cif)
  end
end

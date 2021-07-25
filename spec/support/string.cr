def string_build_via_utf16(& : IO -> _)
  io = IO::Memory.new
  io.set_encoding("UTF-16LE")
  yield io
  byte_slice = io.to_slice
  utf16_slice = Slice.new(byte_slice.to_unsafe.unsafe_as(Pointer(UInt16)), byte_slice.size // sizeof(UInt16))
  String.from_utf16(utf16_slice)
end

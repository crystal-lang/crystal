require "crystal/system/win32/pe"

struct Exception::CallStack
  DEBUG_LINE_STR = ".debug_line_str"
  DEBUG_STR      = ".debug_str"
  DEBUG_LINE     = ".debug_line"
  DEBUG_ABBREV   = ".debug_abbrev"
  DEBUG_INFO     = ".debug_info"

  @@coff_symbols : Hash(Int32, Array(Crystal::System::PE::COFFSymbol))?

  protected def self.load_debug_info_impl : Nil
    # DWARF debug info is read on demand, only for the program counters of
    # the exception being decoded; only the COFF symbols used by
    # `Exception::CallStack.dladdr` are kept in memory
    program = Process.executable_path
    return unless program && File::Info.readable? program

    Crystal::System::PE.open(program) do |image|
      @@coff_symbols = image.read_coff_symbols
    end
  rescue ex
    @@coff_symbols = nil
  end

  # Opens the image containing the DWARF sections for the current program
  # and yields it together with the base address of the program, keeping the
  # image mapped only for the duration of the block.
  protected def self.open_debug_image(&)
    program = Process.executable_path
    return unless program && File::Info.readable? program

    ret = LibC.GetModuleHandleExW(LibC::GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, nil, out hmodule)
    return if ret == 0

    Crystal::System::PE.open(program) do |image|
      yield image, hmodule.address &- image.original_image_base
    end
  end

  protected def self.decode_address(ip)
    ip.address
  end
end

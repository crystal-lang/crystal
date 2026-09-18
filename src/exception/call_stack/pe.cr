require "crystal/system/win32/pe"

struct Exception::CallStack
  DEBUG_LINE_STR = ".debug_line_str"
  DEBUG_STR      = ".debug_str"
  DEBUG_LINE     = ".debug_line"
  DEBUG_ABBREV   = ".debug_abbrev"
  DEBUG_INFO     = ".debug_info"

  @@base_address = 0_u64
  @@coff_symbols : Hash(Int32, Array(Crystal::System::PE::COFFSymbol))?

  protected def self.load_debug_info_impl : Nil
    return unless path = Process.executable_path
    return if LibC.GetModuleHandleExW(LibC::GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, nil, out hmodule) == 0
    return unless program = Crystal::System::PE.open(path)

    @@base_address = hmodule.address - program.original_image_base
    @@coff_symbols = program.read_coff_symbols

    preload_dwarf_sections(program)
  end

  protected def self.decode_address(ip)
    ip.address &- @@base_address
  end
end

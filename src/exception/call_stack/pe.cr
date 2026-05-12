require "crystal/pe"

struct Exception::CallStack
  DEBUG_LINE_STR = ".debug_line_str"
  DEBUG_STR      = ".debug_str"
  DEBUG_LINE     = ".debug_line"
  DEBUG_ABBREV   = ".debug_abbrev"
  DEBUG_INFO     = ".debug_info"

  @@coff_symbols : Hash(Int32, Array(Crystal::PE::COFFSymbol))?

  def self.load_debug_info : Nil
    # FIXME: Crystal::PE depends on the event loop (it shouldn't)
    previous_def if Crystal::EventLoop.current?
  end

  protected def self.load_debug_info_impl : Nil
    program = Process.executable_path
    return unless program && File::Info.readable? program

    ret = LibC.GetModuleHandleExW(LibC::GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, nil, out hmodule)
    return if ret == 0

    Crystal::PE.open(program) do |image|
      @@coff_symbols = image.coff_symbols
      read_dwarf_sections(image, hmodule.address - image.original_image_base)
    end
  rescue ex
    @@dwarf_line_numbers = nil
    @@dwarf_function_names = nil
  end

  protected def self.decode_address(ip)
    ip.address
  end
end

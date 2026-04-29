require "crystal/elf"
{% unless flag?(:wasm32) %}
  require "c/link"
{% end %}

struct Exception::CallStack
  DEBUG_LINE_STR = ".debug_line_str"
  DEBUG_STR      = ".debug_str"
  DEBUG_LINE     = ".debug_line"
  DEBUG_ABBREV   = ".debug_abbrev"
  DEBUG_INFO     = ".debug_info"

  private struct DlPhdrData
    getter program : String
    property base_address : LibC::Elf_Addr = 0

    def initialize(@program : String)
    end
  end

  def self.load_debug_info : Nil
    # FIXME: Crystal::ELF depends on the event loop (it shouldn't)
    previous_def if Crystal::EventLoop.current?
  end

  protected def self.load_debug_info_impl : Nil
    program = Process.executable_path
    return unless program && File::Info.readable? program

    data = DlPhdrData.new(program)

    phdr_callback = LibC::DlPhdrCallback.new do |info, size, data|
      # `dl_iterate_phdr` does not always visit the current program first; on
      # Android the first object is `/system/bin/linker64`, the second is the
      # full program path (not the empty string), so we check both here
      name_c_str = info.value.name
      if name_c_str && (name_c_str.value == 0 || LibC.strcmp(name_c_str, data.as(DlPhdrData*).value.program) == 0)
        # The first entry is the header for the current program.
        # Note that we avoid allocating here and just store the base address
        # to be passed to self.read_dwarf_sections when dl_iterate_phdr returns.
        # Calling self.read_dwarf_sections from this callback may lead to reallocations
        # and deadlocks due to the internal lock held by dl_iterate_phdr (#10084).
        data.as(DlPhdrData*).value.base_address = info.value.addr
        1
      else
        0
      end
    end

    LibC.dl_iterate_phdr(phdr_callback, pointerof(data))

    Crystal::ELF.open(data.program) do |image|
      read_dwarf_sections(image, data.base_address)
    end
  rescue ex
    @@dwarf_line_numbers = nil
    @@dwarf_function_names = nil
  end

  protected def self.decode_address(ip)
    ip.address
  end
end

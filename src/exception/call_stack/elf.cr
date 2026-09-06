require "crystal/system/unix/elf"
{% unless flag?(:wasm32) %}
  require "c/link"
{% end %}

{% if flag?(:musl) %}
  lib LibC
    $__ehdr_start : Char
  end
{% end %}

struct Exception::CallStack
  DEBUG_LINE_STR = ".debug_line_str"
  DEBUG_STR      = ".debug_str"
  DEBUG_LINE     = ".debug_line"
  DEBUG_ABBREV   = ".debug_abbrev"
  DEBUG_INFO     = ".debug_info"

  @@base_address = LibC::Elf_Addr.zero

  private struct DlPhdrData
    getter program : String
    property base_address : LibC::Elf_Addr = 0

    def initialize(@program : String)
    end
  end

  protected def self.load_debug_info_impl : Nil
    return unless path = Process.executable_path
    return unless program = Crystal::System::ELF.open(path)

    load_base_address(path, program)
    preload_dwarf_sections(program)
  end

  # Determine the address offset at which the program was loaded at.
  private def self.load_base_address(path, program)
    data = DlPhdrData.new(path)

    phdr_callback = LibC::DlPhdrCallback.new do |info, size, data|
      # `dl_iterate_phdr` does not always visit the current program first; on
      # Android the first object is `/system/bin/linker64`, the second is the
      # full program path (not the empty string), so we check both here
      name_c_str = info.value.name
      if name_c_str && (name_c_str.value == 0 || LibC.strcmp(name_c_str, data.as(DlPhdrData*).value.program) == 0)
        # The first entry is the header for the current program.
        data.as(DlPhdrData*).value.base_address = info.value.addr
        1
      else
        0
      end
    end

    LibC.dl_iterate_phdr(phdr_callback, pointerof(data))

    {% if flag?(:musl) %}
      # musl-libc when linked with -static-pie correctly loads the program at
      # a random address, but dl_iterate_phdr reports the base address as
      # zero; musl-libc doesn't implement dladdr1 (RTLD_DL_LINKMAP) or
      # populate the _r_debug symbol either, so we fallback to use the address
      # at which the ELF file has been loaded
      if data.base_address == 0 && program.pie?
        data.base_address = LibC::Elf_Addr.new(pointerof(LibC.__ehdr_start).address)
      end
    {% end %}

    @@base_address = data.base_address
  end

  protected def self.decode_address(ip)
    ip.address &- @@base_address
  end
end

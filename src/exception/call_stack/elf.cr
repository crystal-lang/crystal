require "crystal/elf"
{% unless flag?(:wasm32) %}
  require "c/link"
{% end %}

struct Exception::CallStack
  protected def self.load_debug_info_impl : Nil
    base_address : LibC::Elf_Addr = 0
    phdr_callback = LibC::DlPhdrCallback.new do |info, size, data|
      # The first entry is the header for the current program.
      # Note that we avoid allocating here and just store the base address
      # to be passed to self.read_dwarf_sections when dl_iterate_phdr returns.
      # Calling self.read_dwarf_sections from this callback may lead to reallocations
      # and deadlocks due to the internal lock held by dl_iterate_phdr (#10084).
      data.as(Pointer(LibC::Elf_Addr)).value = info.value.addr
      1
    end

    LibC.dl_iterate_phdr(phdr_callback, pointerof(base_address))
    self.read_dwarf_sections(base_address)
  end

  protected def self.read_dwarf_sections(base_address = 0)
    program = Process.executable_path
    return unless program && File.readable? program
    Crystal::ELF.open(program) do |elf|
      line_strings = elf.read_section?(".debug_line_str") do |sh, io|
        Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
      end

      strings = elf.read_section?(".debug_str") do |sh, io|
        Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
      end

      elf.read_section?(".debug_line") do |sh, io|
        @@dwarf_line_numbers = Crystal::DWARF::LineNumbers.new(io, sh.size, base_address, strings, line_strings)
      end

      elf.read_section?(".debug_info") do |sh, io|
        names = [] of {LibC::SizeT, LibC::SizeT, String}

        while (offset = io.pos - sh.offset) < sh.size
          info = Crystal::DWARF::Info.new(io, offset)

          elf.read_section?(".debug_abbrev") do |sh, io|
            info.read_abbreviations(io)
          end

          parse_function_names_from_dwarf(info, strings, line_strings) do |low_pc, high_pc, name|
            names << {low_pc + base_address, high_pc + base_address, name}
          end
        end

        @@dwarf_function_names = names
      end
    end
  end

  protected def self.decode_address(ip)
    ip.address
  end
end

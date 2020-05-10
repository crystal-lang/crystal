require "crystal/elf"

struct Exception::CallStack
  @@base_address : UInt64 | UInt32 | Nil

  protected def self.read_dwarf_sections
    program = Process.executable_path
    return unless program && File.readable? program
    Crystal::ELF.open(program) do |elf|
      elf.read_section?(".text") do |sh, _|
        @@base_address = sh.addr - sh.offset
      end

      elf.read_section?(".debug_line") do |sh, io|
        @@dwarf_line_numbers = Crystal::DWARF::LineNumbers.new(io, sh.size)
      end

      strings = elf.read_section?(".debug_str") do |sh, io|
        Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
      end

      elf.read_section?(".debug_info") do |sh, io|
        names = [] of {LibC::SizeT, LibC::SizeT, String}

        while (offset = io.pos - sh.offset) < sh.size
          info = Crystal::DWARF::Info.new(io, offset)

          elf.read_section?(".debug_abbrev") do |sh, io|
            info.read_abbreviations(io)
          end

          parse_function_names_from_dwarf(info, strings) do |name, low_pc, high_pc|
            names << {name, low_pc, high_pc}
          end
        end

        @@dwarf_function_names = names
      end
    end
  end

  # DWARF uses fixed addresses but some platforms (e.g., OpenBSD or Linux
  # with the [PaX patch](https://en.wikipedia.org/wiki/PaX)) load
  # executables at a random address, so we must remove the load offset from
  # the IP to match the addresses in DWARF sections.
  #
  # See https://en.wikipedia.org/wiki/Address_space_layout_randomization
  protected def self.decode_address(ip)
    if LibC.dladdr(ip, out info) != 0
      unless info.dli_fbase.address == @@base_address
        return ip.address - info.dli_fbase.address
      end
    end
    ip.address
  end
end

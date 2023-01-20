require "crystal/mach_o"

lib LibC
  fun _dyld_image_count : UInt32
  fun _dyld_get_image_name(image_index : UInt32) : Char*
  fun _dyld_get_image_vmaddr_slide(image_index : UInt32) : Long
end

struct Exception::CallStack
  @@image_slide : LibC::Long?

  protected def self.load_debug_info_impl
    read_dwarf_sections
  end

  protected def self.read_dwarf_sections
    locate_dsym_bundle do |mach_o|
      line_strings = mach_o.read_section?("__debug_line_str") do |sh, io|
        Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
      end

      strings = mach_o.read_section?("__debug_str") do |sh, io|
        Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
      end

      mach_o.read_section?("__debug_line") do |sh, io|
        @@dwarf_line_numbers = Crystal::DWARF::LineNumbers.new(io, sh.size, strings: strings, line_strings: line_strings)
      end

      mach_o.read_section?("__debug_info") do |sh, io|
        names = [] of {LibC::SizeT, LibC::SizeT, String}

        while (offset = io.pos - sh.offset) < sh.size
          info = Crystal::DWARF::Info.new(io, offset)

          mach_o.read_section?("__debug_abbrev") do |sh, io|
            info.read_abbreviations(io)
          end

          parse_function_names_from_dwarf(info, strings, line_strings) do |low_pc, high_pc, name|
            names << {low_pc, high_pc, name}
          end
        end

        @@dwarf_function_names = names
      end
    end
  end

  # DWARF uses fixed addresses but Darwin loads executables at a random
  # address, so we must remove the load offset from the IP to match the
  # addresses in DWARF sections.
  #
  # See https://en.wikipedia.org/wiki/Address_space_layout_randomization
  protected def self.decode_address(ip)
    ip.address - image_slide
  end

  # Searches the companion dSYM bundle with the DWARF sections for the
  # current program as generated by `dsymutil`. It may be a `foo.dwarf` file
  # or within a `foo.dSYM` bundle for a program named `foo`.
  #
  # See <http://wiki.dwarfstd.org/index.php?title=Apple%27s_%22Lazy%22_DWARF_Scheme> for details.
  private def self.locate_dsym_bundle(&)
    program = Process.executable_path
    return unless program

    files = {
      "#{program}.dSYM/Contents/Resources/DWARF/#{File.basename(program)}",
      "#{program}.dwarf",
    }

    files.each do |dwarf|
      next unless File.exists?(dwarf)

      Crystal::MachO.open(program) do |mach_o|
        Crystal::MachO.open(dwarf) do |dsym|
          if dsym.uuid == mach_o.uuid
            return yield dsym
          end
        end
      end
    end

    nil
  end

  # The address offset at which the program was loaded at.
  private def self.image_slide
    @@image_slide ||= search_image_slide
  end

  private def self.search_image_slide
    buffer = GC.malloc_atomic(LibC::PATH_MAX).as(UInt8*)
    size = LibC::PATH_MAX.to_u32

    if LibC._NSGetExecutablePath(buffer, pointerof(size)) == -1
      buffer = GC.malloc_atomic(size).as(UInt8*)
      if LibC._NSGetExecutablePath(buffer, pointerof(size)) == -1
        return LibC::Long.new(0)
      end
    end

    program = File.realpath(String.new(buffer))

    LibC._dyld_image_count.times do |i|
      if program == File.realpath(String.new(LibC._dyld_get_image_name(i)))
        return LibC._dyld_get_image_vmaddr_slide(i)
      end
    end

    LibC::Long.new(0)
  end
end

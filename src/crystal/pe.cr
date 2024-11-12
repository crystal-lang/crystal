module Crystal
  # :nodoc:
  #
  # Portable Executable reader.
  #
  # Documentation:
  # - <https://learn.microsoft.com/en-us/windows/win32/debug/pe-format>
  struct PE
    class Error < Exception
    end

    record SectionHeader, name : String, virtual_offset : UInt32, offset : UInt32, size : UInt32

    record COFFSymbol, offset : UInt32, name : String

    # addresses in COFF debug info are relative to this image base; used by
    # `Exception::CallStack.read_dwarf_sections` to calculate the real relocated
    # addresses
    getter original_image_base : UInt64

    @section_headers : Slice(SectionHeader)
    @string_table_base : UInt32

    # mapping from zero-based section index to list of symbols sorted by
    # offsets within that section
    getter coff_symbols = Hash(Int32, Array(COFFSymbol)).new

    def self.open(path : String | ::Path, &)
      File.open(path, "r") do |file|
        yield new(file)
      end
    end

    def initialize(@io : IO::FileDescriptor)
      dos_header = uninitialized LibC::IMAGE_DOS_HEADER
      io.read_fully(pointerof(dos_header).to_slice(1).to_unsafe_bytes)
      raise Error.new("Invalid DOS header") unless dos_header.e_magic == 0x5A4D # MZ

      io.seek(dos_header.e_lfanew)
      nt_header = uninitialized LibC::IMAGE_NT_HEADERS
      io.read_fully(pointerof(nt_header).to_slice(1).to_unsafe_bytes)
      raise Error.new("Invalid PE header") unless nt_header.signature == 0x00004550 # PE\0\0

      @original_image_base = nt_header.optionalHeader.imageBase
      @string_table_base = nt_header.fileHeader.pointerToSymbolTable + nt_header.fileHeader.numberOfSymbols * sizeof(LibC::IMAGE_SYMBOL)

      section_count = nt_header.fileHeader.numberOfSections
      nt_section_headers = Pointer(LibC::IMAGE_SECTION_HEADER).malloc(section_count).to_slice(section_count)
      io.read_fully(nt_section_headers.to_unsafe_bytes)

      @section_headers = nt_section_headers.map do |nt_header|
        if nt_header.name[0] === '/'
          # section name is longer than 8 bytes; look up the COFF string table
          name_buf = nt_header.name.to_slice + 1
          string_offset = String.new(name_buf.to_unsafe, name_buf.index(0) || name_buf.size).to_i
          io.seek(@string_table_base + string_offset)
          name = io.gets('\0', chomp: true).not_nil!
        else
          name = String.new(nt_header.name.to_unsafe, nt_header.name.index(0) || nt_header.name.size)
        end

        SectionHeader.new(name: name, virtual_offset: nt_header.virtualAddress, offset: nt_header.pointerToRawData, size: nt_header.virtualSize)
      end

      io.seek(nt_header.fileHeader.pointerToSymbolTable)
      image_symbol_count = nt_header.fileHeader.numberOfSymbols
      image_symbols = Pointer(LibC::IMAGE_SYMBOL).malloc(image_symbol_count).to_slice(image_symbol_count)
      io.read_fully(image_symbols.to_unsafe_bytes)

      aux_count = 0
      image_symbols.each_with_index do |sym, i|
        if aux_count == 0
          aux_count = sym.numberOfAuxSymbols.to_i
        else
          aux_count &-= 1
        end

        next unless aux_count == 0
        next unless sym.type.bits_set?(0x20) # COFF function
        next unless sym.sectionNumber > 0    # one-based section index
        next unless sym.storageClass.in?(LibC::IMAGE_SYM_CLASS_EXTERNAL, LibC::IMAGE_SYM_CLASS_STATIC)

        if sym.n.name.short == 0
          io.seek(@string_table_base + sym.n.name.long)
          name = io.gets('\0', chomp: true).not_nil!
        else
          name = String.new(sym.n.shortName.to_slice).rstrip('\0')
        end

        # `@coff_symbols` uses zero-based indices
        section_coff_symbols = @coff_symbols.put_if_absent(sym.sectionNumber.to_i &- 1) { [] of COFFSymbol }
        section_coff_symbols << COFFSymbol.new(sym.value, name)
      end

      # add one sentinel symbol to ensure binary search on the offsets works
      @coff_symbols.each_with_index do |(_, symbols), i|
        symbols.sort_by!(&.offset)
        symbols << COFFSymbol.new(@section_headers[i].size, "??")
      end
    end

    def read_section?(name : String, &)
      if sh = @section_headers.find(&.name.== name)
        @io.seek(sh.offset) do
          yield sh, @io
        end
      end
    end
  end
end

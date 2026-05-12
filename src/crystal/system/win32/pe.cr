require "c/fileapi"
require "c/memoryapi"
require "c/winbase"

class Crystal::System::PE
  record COFFSymbol, offset : UInt32, name : String

  def self.open(path : String, &)
    wpath = Crystal::System.to_wstr(path)
    file_handle = LibC.CreateFileW(wpath, LibC::FILE_GENERIC_READ, LibC::DEFAULT_SHARE_MODE, nil, LibC::OPEN_EXISTING, 0, nil)
    return if file_handle == LibC::INVALID_HANDLE_VALUE

    begin
      return if LibC.GetFileInformationByHandle(file_handle, out info) == 0
      size = LibC::SizeT.new((info.nFileSizeHigh.to_u64 << 32) | info.nFileSizeLow.to_u64)

      map_handle = LibC.CreateFileMappingA(file_handle, nil, LibC::PAGE_READONLY, info.nFileSizeHigh, info.nFileSizeLow, nil)
      return if map_handle == LibC::INVALID_HANDLE_VALUE

      begin
        pointer = LibC.MapViewOfFile(map_handle, LibC::FILE_MAP_READ, 0, 0, size)
        return if pointer.null?

        begin
          program = new(pointer.as(UInt8*), size)
          yield program if program.valid?
        ensure
          LibC.UnmapViewOfFile(pointer)
        end
      ensure
        LibC.CloseHandle(map_handle)
      end
    ensure
      LibC.CloseHandle(file_handle)
    end
  end

  @nt_header = Pointer(LibC::IMAGE_NT_HEADERS).null
  @symbol_table = Pointer(UInt8).null

  def initialize(@pointer : UInt8*, @size : LibC::SizeT)
  end

  # File is a PE file for the current architecture.
  def valid?
    dos_header.value.e_magic == 0x5A4D &&     # MZ
      nt_header.value.signature == 0x00004550 # PE\0\0
  end

  def section?(name : String, &)
    sh = (nt_header + 1).as(LibC::IMAGE_SECTION_HEADER*)

    nt_header.value.fileHeader.numberOfSections.times do
      if name_equal?(name, section_name(sh.value.name.to_slice))
        bytes = Bytes.new(@pointer + sh.value.pointerToRawData, sh.value.virtualSize)
        return yield bytes, sh.value.pointerToRawData.to_i64
      end
      sh += 1
    end
  end

  private def section_name(bytes)
    if bytes[0] === '/'
      # section name is longer than 8 bytes: look up the COFF string table
      long_section_name(bytes + 1)
    else
      bytes.to_unsafe
    end
  end

  private def long_section_name(bytes)
    offset = 0
    bytes.each do |byte|
      break if byte.zero?
      offset = (offset * 10) + byte - '0'.ord
    end
    symbol_table + offset
  end

  private def name_equal?(name : String, pointer : UInt8*) : Bool
    name.to_slice.each do |byte|
      return false if pointer.value == 0_u8 || pointer.value != byte
      pointer += 1
    end
    pointer.value == 0_u8
  end

  def image_symbols : Slice(LibC::IMAGE_SYMBOL)
    pointer = @pointer + nt_header.value.fileHeader.pointerToSymbolTable
    size = nt_header.value.fileHeader.numberOfSymbols
    Slice.new(pointer.as(LibC::IMAGE_SYMBOL*), size)
  end

  # Mapping from zero-based section index to list of symbols sorted by offsets
  # within that section.
  def read_coff_symbols : Hash(Int32, Array(COFFSymbol))
    symbols = Hash(Int32, Array(COFFSymbol)).new { [] of COFFSymbol }

    image_symbols = self.image_symbols
    sym = image_symbols.to_unsafe
    limit = sym + image_symbols.size

    while sym < limit
      # skip aux symbols
      if aux_count = sym.value.numberOfAuxSymbols
        sym += aux_count
      end

      if filter_coff_symbol?(sym)
        # from 1-based (coff) to 0-based (crystal) indices
        index = sym.value.sectionNumber.to_i &- 1
        symbols[index] << COFFSymbol.new(sym.value.value, coff_symbol_name(sym))
      end

      sym += 1
    end

    # add sentinels to ensure binary search on the offsets works
    sh = (nt_header + 1).as(LibC::IMAGE_SECTION_HEADER*)
    symbols.each do |_, symbols|
      symbols.sort_by!(&.offset)
      symbols << COFFSymbol.new(sh.value.virtualSize, "??")
      sh += 1
    end

    symbols
  end

  private def filter_coff_symbol?(sym)
    return false unless sym.value.type.bits_set?(0x20) # COFF function
    return false unless sym.value.sectionNumber > 0    # 1-based section index
    return false unless sym.value.storageClass.in?(LibC::IMAGE_SYM_CLASS_EXTERNAL, LibC::IMAGE_SYM_CLASS_STATIC)
    true
  end

  # TODO: extract to Crystal::COFF type (?)
  private def coff_symbol_name(sym)
    pointer =
      if sym.value.n.name.short == 0
        symbol_table + sym.value.n.name.long
      else
        sym.value.n.shortName.to_unsafe
      end
    String.new(pointer)
  end

  def original_image_base : UInt64
    nt_header.value.optionalHeader.imageBase
  end

  def symbol_table
    @symbol_table ||= @pointer + (nt_header.value.fileHeader.pointerToSymbolTable +
                                  nt_header.value.fileHeader.numberOfSymbols * sizeof(LibC::IMAGE_SYMBOL))
  end

  private def dos_header
    @pointer.as(LibC::IMAGE_DOS_HEADER*)
  end

  private def nt_header
    @nt_header ||= (@pointer + dos_header.value.e_lfanew).as(LibC::IMAGE_NT_HEADERS*)
  end
end

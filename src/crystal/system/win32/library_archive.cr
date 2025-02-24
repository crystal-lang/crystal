# This module provides functions for operating with Windows library archives.
# Implementation based on: https://docs.microsoft.com/en-us/windows/win32/debug/pe-format
module Crystal::System::LibraryArchive
  # Returns the list of DLL filenames imported by the .lib archive at the given
  # *path*.
  def self.imported_dlls(path : ::Path | String) : Set(String)
    return Set(String).new unless ::File.file?(path)
    ::File.open(path, "r") do |f|
      reader = COFFReader.new(f)
      reader.run
      reader.dlls
    end
  end

  # Minimal implementation of a Microsoft COFF archive reader. All unused fields
  # are ignored.
  private struct COFFReader
    getter dlls = Set(String).new

    # MSVC-style import libraries include the `__NULL_IMPORT_DESCRIPTOR` symbol,
    # MinGW-style ones do not
    getter? msvc = false

    def initialize(@ar : ::File)
    end

    # Attempts to collect all DLL imports found in an import library. Should not
    # raise if the library is not an import library. Might raise if `@ar` is not
    # a library at all.
    def run
      file_size = @ar.size

      # magic number
      return unless @ar.read_string(8) == "!<arch>\n"

      # first linker member's filename is `/`
      # second linker member's filename is also `/` (apparently not all linkers generate this?)
      # longnames member's filename is `//` (optional)
      # the rest are standard members
      first = true
      until @ar.pos == file_size
        read_member do |filename, io|
          if first
            first = false
            return unless filename == "/"
            handle_first_member(io)
          elsif !filename.in?("/", "//")
            handle_standard_member(io)
          end
        end
      end
    end

    private def read_member(& : String ->)
      filename = @ar.read_string(16).rstrip(' ')

      # time(12) + uid(6) + gid(6) + mode(8)
      @ar.skip(32)

      size = @ar.read_string(10).rstrip(' ').to_u32

      # end of header
      return unless @ar.read_string(2) == "`\n"

      new_pos = @ar.pos + size + (size.odd? ? 1 : 0)
      yield filename, IO::Sized.new(@ar, read_size: size)
      @ar.seek(new_pos)
    end

    private def handle_first_member(io)
      symbol_count = io.read_bytes(UInt32, IO::ByteFormat::BigEndian)

      # 4-byte offset per symbol
      io.skip(symbol_count * 4)

      symbol_count.times do
        symbol = io.gets('\0', chomp: true)
        if symbol == "__NULL_IMPORT_DESCRIPTOR"
          @msvc = true
          break
        end
      end
    end

    private def handle_standard_member(io)
      machine = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
      section_count = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)

      if machine == 0x0000 && section_count == 0xFFFF
        # short import library
        version = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
        return unless version == 0 # 1 and 2 are used by object files (ANON_OBJECT_HEADER)

        # machine(2) + time(4) + size(4) + ordinal/hint(2) + flags(2)
        io.skip(14)

        # TODO: is there a way to do this without constructing a temporary string,
        # but with the optimizations present in `IO#gets`?
        return unless io.gets('\0') # symbol name

        if dll_name = io.gets('\0', chomp: true)
          @dlls << dll_name if valid_dll?(dll_name)
        end
      else
        # long import library, code based on GNU binutils `dlltool -I`:
        # https://sourceware.org/git/?p=binutils-gdb.git;a=blob;f=binutils/dlltool.c;hb=967dc35c78adb85ee1e2e596047d9dc69107a9db#l3231

        # timeDateStamp(4) + pointerToSymbolTable(4) + numberOfSymbols(4) + sizeOfOptionalHeader(2) + characteristics(2)
        io.skip(16)

        section_count.times do |i|
          section_header = uninitialized LibC::IMAGE_SECTION_HEADER
          return unless io.read_fully?(pointerof(section_header).to_slice(1).to_unsafe_bytes)

          name = String.new(section_header.name.to_unsafe, section_header.name.index(0) || section_header.name.size)
          next unless name == (msvc? ? ".idata$6" : ".idata$7")

          if msvc? ? section_header.characteristics.bits_set?(LibC::IMAGE_SCN_CNT_INITIALIZED_DATA) : section_header.pointerToRelocations == 0
            bytes_read = sizeof(LibC::IMAGE_FILE_HEADER) + sizeof(LibC::IMAGE_SECTION_HEADER) * (i + 1)
            io.skip(section_header.pointerToRawData - bytes_read)
            if dll_name = io.gets('\0', chomp: true, limit: section_header.sizeOfRawData)
              @dlls << dll_name if valid_dll?(dll_name)
            end
          end

          return
        end
      end
    end

    private def valid_dll?(name)
      name.size >= 5 && name[-4..].compare(".dll", case_insensitive: true) == 0
    end
  end
end

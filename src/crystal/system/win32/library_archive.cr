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

    def initialize(@ar : ::File)
    end

    # Attempts to collect all DLL imports found in an import library. Should not
    # raise if the library is not an import library. Might raise if `@ar` is not
    # a library at all.
    def run
      file_size = @ar.size

      # magic number
      return unless @ar.read_string(8) == "!<arch>\n"

      # first linker member
      return unless read_member { |filename, _| return unless filename == "/" }

      # second linker member
      return unless read_member { |filename, _| return unless filename == "/" }

      # longnames member (optional)
      return if @ar.pos == file_size
      return unless read_member { |filename, io| handle_standard_member(io) unless filename == "//" }

      # standard members
      until @ar.pos == file_size
        return unless read_member { |_, io| handle_standard_member(io) }
      end
    end

    private def read_member(& : String ->)
      filename = @ar.read_string(16).rstrip(' ')

      # time(12) + uid(6) + gid(6) + mode(8)
      @ar.skip(32)

      size = @ar.read_string(10).rstrip(' ').to_u32

      # end of header
      return false unless @ar.read_string(2) == "`\n"

      new_pos = @ar.pos + size + (size.odd? ? 1 : 0)
      yield filename, IO::Sized.new(@ar, read_size: size)
      @ar.seek(new_pos)

      true
    end

    private def handle_standard_member(io)
      sig1 = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
      return unless sig1 == 0x0000 # IMAGE_FILE_MACHINE_UNKNOWN

      sig2 = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
      return unless sig2 == 0xFFFF

      version = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
      return unless version == 0 # 1 and 2 are used by object files (ANON_OBJECT_HEADER)

      # machine(2) + time(4) + size(4) + ordinal/hint(2) + flags(2)
      io.skip(14)

      # TODO: is there a way to do this without constructing a temporary string,
      # but with the optimizations present in `IO#gets`?
      return unless io.gets('\0') # symbol name

      if dll_name = io.gets('\0', chomp: true)
        @dlls << dll_name
      end
    end
  end
end

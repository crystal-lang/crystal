# :nodoc:
struct CallStack
  # ELF reader.
  #
  # Documentation:
  # - <http://www.sco.com/developers/gabi/latest/contents.html>
  #
  # :nodoc:
  struct ELF
    MAGIC = UInt8.slice(0x7f, 'E'.ord, 'L'.ord, 'F'.ord)

    enum Klass : UInt8
      ELF32 = 1
      ELF64 = 2
    end

    enum OSABI : UInt8
      SYSTEM_V = 0x00
      HP_UX    = 0x01
      NETBSD   = 0x02
      LINUX    = 0x03
      SOLARIS  = 0x06
      AIX      = 0x07
      IRIX     = 0x08
      FREEBSD  = 0x09
      OPENBSD  = 0x0C
      OPENVMS  = 0x0D
      NSK_OS   = 0x0E
      AROS     = 0x0F
      FENIS_OS = 0x10
      CLOUDABI = 0x11
      SORTIX   = 0x53
    end

    enum Type : UInt16
      REL = 1
      EXEC = 2
      DYN = 3
      CORE = 4
    end

    enum Machine : UInt16
      UNKNOWN = 0x00
      SPARC   = 0x02
      X86     = 0x03
      MIPS    = 0x08
      POWERPC = 0x14
      ARM     = 0x28
      SUPERH  = 0x2A
      IA_64   = 0x32
      X86_64  = 0x3E
      AARCH64 = 0xB7
    end

    struct Ident
      property klass : Klass
      property data : IO::ByteFormat
      property version : UInt8
      property osabi : OSABI
      property abiversion : UInt8

      def initialize(@klass, @data, @version, @osabi, @abiversion)
      end
    end

    struct SectionHeader
      enum Type : UInt32
        NULL = 0
        PROGBITS = 1
        SYMTAB = 2
        STRTAB = 3
        RELA = 4
        HASH = 5
        DYNAMIC = 6
        NOTE = 7
        NOBITS = 8
        REL = 9
        SHLIB = 10
        DYNSYM = 11
        INIT_ARRAY = 14
        FINI_ARRAY = 15
        PREINIT_ARRAY = 16
        GROUP = 17
        SYMTAB_SHNDX = 18
      end

      @[Flags]
      enum Flags : UInt64
        WRITE = 0x1
        ALLOC = 0x2
        EXECINSTR = 0x4
        MERGE = 0x10
        STRINGS = 0x20
        INFO_LINK = 0x40
        LINK_ORDER = 0x80
        OS_NONCONFORMING = 0x100
        GROUP = 0x200
        TLS = 0x400
        COMPRESSED = 0x800
        MASKOS = 0x0ff00000
        MASKPROC = 0xf0000000

        def short
          String.build do |str|
            str << "W" if write?
            str << "A" if alloc?
            str << "X" if execinstr?
            str << "M" if merge?
            str << "S" if strings?
            str << "T" if tls?
          end
        end
      end

      property! name : UInt32
      property! type : Type
      property! flags : Flags
      property! addr : UInt32|UInt64
      property! offset : UInt32|UInt64
      property! size : UInt32|UInt64
      property! link : UInt32
      property! info : UInt32
      property! addralign : UInt32|UInt64
      property! entsize : UInt32|UInt64
    end

    class Error < Exception
    end

    getter! ident : Ident
    property! type : Type
    property! machine : Machine
    property! version : UInt32
    property! entry : UInt32|UInt64
    property! phoff : UInt32|UInt64
    property! shoff : UInt32|UInt64
    property! flags : UInt32
    property! ehsize : UInt16
    property! phentsize : UInt16
    property! phnum : UInt16
    property! shentsize : UInt16
    property! shnum : UInt16
    property! shstrndx : UInt16

    def initialize(@io : IO::FileDescriptor)
      read_magic
      read_ident
      read_header
    end

    private def read_magic
      @io.read(magic = Slice(UInt8).new(4))
      raise Error.new("Invalid magic number") unless magic == MAGIC
    end

    private def read_ident
      ei_class = Klass.new(@io.read_byte.not_nil!)

      ei_data = case @io.read_byte.not_nil!
                when 1 then IO::ByteFormat::LittleEndian
                when 2 then IO::ByteFormat::BigEndian
                else raise Error.new("Unsupported endian format")
                end

      ei_version = @io.read_byte.not_nil!
      raise Error.new("Unsupported version number") unless ei_version == 1

      ei_osabi = OSABI.from_value(@io.read_byte)
      ei_abiversion = @io.read_byte.not_nil!

      @io.skip(7) # padding (unused)

      @ident = Ident.new(ei_class, ei_data, ei_version, ei_osabi, ei_abiversion)
    end

    # Parses and returns an Array of `SectionHeader`.
    def section_headers
      @sections ||= Array(SectionHeader).new(shnum.to_i) do |i|
        @io.seek(shoff + i * shentsize)

        sh = SectionHeader.new
        sh.name = read_word
        sh.type = SectionHeader::Type.new(read_word)
        sh.flags = SectionHeader::Flags.new(read_ulong.to_u64)
        sh.addr = read_ulong
        sh.offset = read_ulong
        sh.size = read_ulong
        sh.link = read_word
        sh.info = read_word
        sh.addralign = read_ulong
        sh.entsize = read_ulong
        sh
      end
    end

    # Returns the name of a section, using the `SectionHeader#name` index.
    def sh_name(index)
      sh = section_headers[shstrndx]
      seek_and_tell(sh.offset + index) do
        @io.gets('\0').to_s.chomp('\0')
      end
    end

    # Searches for a section then yield the `SectionHeader` and the IO object
    # ready for parsing if the section was found. Returns the valure returned by
    # the block or nil if the section wasn't found.
    def read_section?(name : String)
      if sh = section_headers.find { |sh| sh_name(sh.name) == name }
        seek_and_tell(sh.offset) do
          yield sh, @io
        end
      end
    end

    private def seek_and_tell(pos)
      memo = @io.tell
      begin
        @io.seek(pos)
        yield
      ensure
        @io.seek(memo)
      end
    end

    private def read_word
      @io.read_bytes(UInt32, ident.data)
    end

    private def read_ulong
      case ident.klass
      when Klass::ELF32 then @io.read_bytes(UInt32, ident.data)
      when Klass::ELF64 then @io.read_bytes(UInt64, ident.data)
      else raise Error.new("unsupported")
      end
    end

    private def read_header
      @type = Type.new(@io.read_bytes(UInt16, ident.data).not_nil!)
      @machine = Machine.new(@io.read_bytes(UInt16, ident.data).not_nil!)

      @version = @io.read_bytes(UInt32, ident.data).not_nil!
      raise Error.new("Unsupported version number") unless version == 1

      @entry = read_ulong
      @phoff = read_ulong
      @shoff = read_ulong

      @flags = @io.read_bytes(UInt32, ident.data)

      @ehsize = @io.read_bytes(UInt16, ident.data)
      case ident.klass
      when Klass::ELF32
        raise Error.new("Header should be 52 bytes for ELF32") unless ehsize == 52
      when Klass::ELF64
        raise Error.new("Header should be 64 bytes for ELF64") unless ehsize == 64
      end

      @phentsize = @io.read_bytes(UInt16, ident.data)
      @phnum = @io.read_bytes(UInt16, ident.data)

      @shentsize = @io.read_bytes(UInt16, ident.data)
      @shnum = @io.read_bytes(UInt16, ident.data)
      @shstrndx = @io.read_bytes(UInt16, ident.data)
    end
  end
end

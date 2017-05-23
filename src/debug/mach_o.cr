module Debug
  # Mach-O parser.
  #
  # Documentation:
  # - <http://www.idea2ic.com/File_Formats/MachORuntime.pdf>
  # - <http://wiki.dwarfstd.org/index.php?title=Apple%27s_%22Lazy%22_DWARF_Scheme>
  struct MachO
    class Error < Exception
    end

    MAGIC    = 0xfeedface
    CIGAM    = 0xcefaedfe
    MAGIC_64 = 0xfeedfacf
    CIGAM_64 = 0xcffaedfe

    ABI64 = 0x01000000

    enum CpuType : Int32
      ANY       = -1
      VAX       =  1
      MC680x0   =  6
      X86       =  7
      X86_64    = 7 | ABI64
      MC98000   = 10
      HPPA      = 11
      ARM       = 12
      MC88000   = 13
      SPARC     = 14
      I860      = 15
      POWERPC   = 18
      POWERPC64 = 18 | ABI64
    end

    enum FileType : UInt32
      OBJECT      = 0x1
      EXECUTE     = 0x2
      FVMLIB      = 0x3
      CORE        = 0x4
      PRELOAD     = 0x5
      DYLIB       = 0x6
      DYLINKER    = 0x7
      BUNDLE      = 0x8
      DYLIB_STUB  = 0x9
      DSYM        = 0xa
      KEXT_BUNDLE = 0xb
    end

    @[Flags]
    enum Flags : UInt32
      NOUNDEFS                =       0x1
      INCRLINK                =       0x2
      DYLDLINK                =       0x4
      BINDATLOAD              =       0x8
      PREBOUND                =      0x10
      SPLIT_SEGS              =      0x20
      LAZY_INIT               =      0x40
      TWOLEVEL                =      0x80
      FORCE_FLAT              =     0x100
      NOMULTIDEFS             =     0x200
      NOFIXPREBINDING         =     0x400
      PREBINDABLE             =     0x800
      ALLMODSBOUND            =    0x1000
      SUBSECTIONS_VIA_SYMBOLS =    0x2000
      CANONICAL               =    0x4000
      WEAK_DEFINES            =    0x8000
      BINDS_TO_WEAK           =   0x10000
      ALLOW_STACK_EXECUTION   =   0x20000
      ROOT_SAFE               =   0x40000
      SETUID_SAFE             =   0x80000
      NO_REEXPORTED_DYLIBS    =  0x100000
      PIE                     =  0x200000
      DEAD_STRIPPABLE_DYLIB   =  0x400000
      HAS_TLV_DESCRIPTORS     =  0x800000
      NO_HEAP_EXECUTION       = 0x1000000
    end

    property magic : UInt32
    property cputype : CpuType
    property cpusubtype : Int32
    property filetype : FileType
    property ncmds : UInt32
    property sizeofcmds : UInt32
    property flags : Flags

    @ldoff : Int64
    @uuid : UUID?
    @symtab : Symtab?
    @stabs : Array(StabEntry)?
    @symbols : Array(Nlist64)?

    def self.open(path)
      File.open(path, "r") do |file|
        yield new(file)
      end
    end

    def initialize(@io : IO::FileDescriptor)
      @magic = read_magic
      @cputype = CpuType.new(@io.read_bytes(Int32, endianness))
      @cpusubtype = @io.read_bytes(Int32, endianness)
      @filetype = FileType.new(@io.read_bytes(UInt32, endianness))
      @ncmds = @io.read_bytes(UInt32, endianness)
      @sizeofcmds = @io.read_bytes(UInt32, endianness)
      @flags = Flags.new(@io.read_bytes(UInt32, endianness))
      @io.skip(4) if abi64? # reserved
      @ldoff = @io.tell
      @segments = [] of Segment64
      @sections = [] of Section64
    end

    private def read_magic
      magic = @io.read_bytes(UInt32)
      unless magic == MAGIC_64 || magic == CIGAM_64 || magic == MAGIC || magic == CIGAM
        raise Error.new("Invalid magic number")
      end
      magic
    end

    def abi64?
      cputype.value & ABI64 == ABI64
    end

    def endianness
      if @magic == MAGIC_64 || @magic == MAGIC
        IO::ByteFormat::SystemEndian
      elsif IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
        IO::ByteFormat::BigEndian
      else
        IO::ByteFormat::LittleEndian
      end
    end

    # :nodoc:
    REQ_DYLD = 0x80000000

    enum LoadCommand : UInt32
      SEGMENT              =  0x1
      SYMTAB               =  0x2
      SYMSEG               =  0x3
      THREAD               =  0x4
      UNIXTHREAD           =  0x5
      LOADFVMLIB           =  0x6
      IDFVMLIB             =  0x7
      IDENT                =  0x8
      FVMFILE              =  0x9
      PREPAGE              =  0xa
      DYSYMTAB             =  0xb
      LOAD_DYLIB           =  0xc
      ID_DYLIB             =  0xd
      LOAD_DYLINKER        =  0xe
      ID_DYLINKER          =  0xf
      PREBOUND_DYLIB       = 0x10
      ROUTINES             = 0x11
      SUB_FRAMEWORK        = 0x12
      SUB_UMBRELLA         = 0x13
      SUB_CLIENT           = 0x14
      SUB_LIBRARY          = 0x15
      TWOLEVEL_HINTS       = 0x16
      PREBIND_CKSUM        = 0x17
      LOAD_WEAK_DYLIB      = 0x18 | REQ_DYLD
      SEGMENT_64           = 0x19
      ROUTINES_64          = 0x1a
      UUID                 = 0x1b
      RPATH                = 0x1c | REQ_DYLD
      CODE_SIGNATURE       = 0x1d
      SEGMENT_SPLIT_INFO   = 0x1e
      REEXPORT_DYLIB       = 0x1f | REQ_DYLD
      LAZY_LOAD_DYLIB      = 0x20
      ENCRYPTION_INFO      = 0x21
      DYLD_INFO            = 0x22
      DYLD_INFO_ONLY       = 0x22 | REQ_DYLD
      LOAD_UPWARD_DYLIB    = 0x23 | REQ_DYLD
      VERSION_MIN_MACOSX   = 0x24
      VERSION_MIN_IPHONEOS = 0x25
      FUNCTION_STARTS      = 0x26
      DYLD_ENVIRONMENT     = 0x27
      MAIN                 = 0x28 | REQ_DYLD
      DATA_IN_CODE         = 0x29
      SOURCE_VERSION       = 0x2A
      DYLIB_CODE_SIGN_DRS  = 0x2B
      ENCRYPTION_INFO_64   = 0x2C
      LINKER_OPTION        = 0x2D
    end

    struct Segment64
      property! segname : String
      property! vmaddr : UInt64
      property! vmsize : UInt64
      property! fileoff : UInt64
      property! filesize : UInt64
      property! maxprot : UInt32
      property! initprot : UInt32
      property! nsects : UInt32
      property! flags : UInt32
    end

    struct UUID
      property bytes : StaticArray(UInt8, 16)

      def initialize(@bytes)
      end

      def ==(other : UUID)
        bytes == other.bytes
      end

      def inspect(io)
        io << bytes.to_slice.hexstring
      end
    end

    struct Section64
      property segment : Segment64
      property! sectname : String
      property! segname : String
      property! addr : UInt64
      property! size : UInt64
      property! offset : UInt32
      property! align : UInt32
      property! reloff : UInt32
      property! nreloc : UInt32
      property! flags : UInt32

      def initialize(@segment)
      end
    end

    struct Symtab
      property! symoff : UInt32
      property! nsyms : UInt32
      property! stroff : UInt32
      property! strsize : UInt32
    end

    enum Stab : UInt8
      GSYM    = 0x20
      FNAME   = 0x22
      FUN     = 0x24
      STSYM   = 0x26
      LCSYM   = 0x28
      BNSYM   = 0x2e
      OPT     = 0x3c
      RSYM    = 0x40
      SLINE   = 0x44
      ENSYM   = 0x4e
      SSYM    = 0x60
      SO      = 0x64
      OSO     = 0x66
      LSYM    = 0x80
      BINCL   = 0x82
      SOL     = 0x84
      PARAMS  = 0x86
      VERSION = 0x88
      OLEVEL  = 0x8A
      PSYM    = 0xa0
      EINCL   = 0xa2
      ENTRY   = 0xa4
      LBRAC   = 0xc0
      EXCL    = 0xc2
      RBRAC   = 0xe0
      BCOMM   = 0xe2
      ECOMM   = 0xe4
      ECOML   = 0xe8
      LENG    = 0xfe
    end

    struct Nlist64
      struct Type
        STAB = 0xe0_u8 # 11100000
        PEXT = 0x10_u8 # 00010000
        EXT  = 0x01_u8 # 00000001
        TYPE = 0x0e_u8 # 00001110
        UNDF = 0x00_u8 # 00000000
        ABS  = 0x02_u8 # 00000010
        SECT = 0x0e_u8 # 00001110
        PBUD = 0x0c_u8 # 00001100
        INDR = 0x0a_u8 # 00001010

        def initialize(@value : UInt8)
        end

        def value
          @value
        end

        def to_unsafe
          @value
        end

        def stab?
          (value & STAB) != 0
        end

        def pext?
          (value & PEXT) == PEXT
        end

        def ext?
          (value & EXT) == EXT
        end

        {% for flag in %w(UNDF ABS SECT PBUD INDR) %}
          def {{flag.downcase.id}}?
            (value & TYPE) == {{flag.id}}
          end
        {% end %}

        def stab
          Stab.new(value) if stab?
        end

        def to_s(io)
          if stab?
            io << "STAB(#{stab})"
            return
          end

          n = [] of String

          n << "PEXT" if pext?
          n << "EXT" if ext?

          if undf?
            n << "UNDF"
          elsif abs?
            n << "ABS"
          elsif sect?
            n << "SECT"
          elsif pbud?
            n << "PBUD"
          elsif indr?
            n << "INDR"
          end

          io << n.join('|')
        end

        def inspect(io)
          to_s(io)
        end
      end

      property! strx : UInt32
      property! type : Type
      property! sect : UInt8
      property! desc : UInt16
      property! value : UInt64

      property name : String
      @name = ""

      def stab?
        type.stab
      end

      def stab
        type.stab
      end

      def inspect(io)
        io << "#{self.class.name}(type=#{type}, name=#{name.inspect}, sect=#{sect}, desc=#{desc}, value=#{value})"
      end
    end

    # Seek to the first matching load command, yields, then returns the value of
    # the block.
    private def seek_to(load_command : LoadCommand)
      seek_to_each(load_command) do |cmd, cmdsize|
        return yield cmdsize
      end
    end

    # Seek to each matching load command, yielding each of them.
    private def seek_to_each(load_command : LoadCommand) : Nil
      @io.seek(@ldoff)

      ncmds.times do
        cmd = LoadCommand.new(@io.read_bytes(UInt32, endianness))
        cmdsize = @io.read_bytes(UInt32, endianness)

        if cmd == load_command
          yield cmd, cmdsize
        else
          @io.skip(cmdsize - 8)
        end
      end
    end

    def segments
      read_segments_and_sections if @segments.empty?
      @segments
    end

    def sections
      read_segments_and_sections if @sections.empty?
      @sections
    end

    private def read_segments_and_sections
      seek_to_each(LoadCommand::SEGMENT_64) do |cmd, cmdsize|
        segment = Segment64.new
        segment.segname = read_name
        segment.vmaddr = @io.read_bytes(UInt64, endianness)
        segment.vmsize = @io.read_bytes(UInt64, endianness)
        segment.fileoff = @io.read_bytes(UInt64, endianness)
        segment.filesize = @io.read_bytes(UInt64, endianness)
        segment.maxprot = @io.read_bytes(UInt32, endianness)
        segment.initprot = @io.read_bytes(UInt32, endianness)
        segment.nsects = @io.read_bytes(UInt32, endianness)
        segment.flags = @io.read_bytes(UInt32, endianness)
        @segments << segment

        segment.nsects.times do
          section = Section64.new(segment)
          section.sectname = read_name
          section.segname = read_name
          section.addr = @io.read_bytes(UInt64, endianness)
          section.size = @io.read_bytes(UInt64, endianness)
          section.offset = @io.read_bytes(UInt32, endianness)
          section.align = @io.read_bytes(UInt32, endianness)
          section.reloff = @io.read_bytes(UInt32, endianness)
          section.nreloc = @io.read_bytes(UInt32, endianness)
          section.flags = @io.read_bytes(UInt32, endianness)
          @io.skip(12)
          @sections << section
        end
      end
    end

    def symtab
      @symtab ||= seek_to(LoadCommand::SYMTAB) do
        symtab = Symtab.new
        symtab.symoff = @io.read_bytes(UInt32, endianness)
        symtab.nsyms = @io.read_bytes(UInt32, endianness)
        symtab.stroff = @io.read_bytes(UInt32, endianness)
        symtab.strsize = @io.read_bytes(UInt32, endianness)
        symtab
      end.not_nil!
    end

    def uuid
      @uuid ||= seek_to(LoadCommand::UUID) do
        bytes = uninitialized UInt8[16]
        @io.read_fully(bytes.to_slice)
        UUID.new(bytes)
      end.not_nil!
    end

    def symbols
      @symbols ||= @io.seek(symtab.symoff) do
        Array(Nlist64).new(symtab.nsyms) do
          nlist = Nlist64.new
          nlist.strx = @io.read_bytes(UInt32, endianness)
          nlist.type = Nlist64::Type.new(@io.read_byte.not_nil!)
          nlist.sect = @io.read_byte.not_nil!
          nlist.desc = @io.read_bytes(UInt16, endianness)
          nlist.value = @io.read_bytes(UInt64, endianness)

          if nlist.strx > 0
            @io.seek(symtab.stroff + nlist.strx) do
              nlist.name = @io.gets('\0').to_s.chomp('\0')
            end
          end

          nlist
        end
      end
    end

    record StabEntry,
      type : Stab,
      name : String,
      sect : UInt8,
      desc : UInt16,
      value : UInt64

    def stabs
      @stabs ||= symbols.compact_map do |nlist|
        if stab = nlist.stab?
          StabEntry.new(stab, nlist.name, nlist.sect, nlist.desc, nlist.value)
        end
      end
    end

    private def read_name
      bytes = uninitialized StaticArray(UInt8, 16)
      @io.read_fully(bytes.to_slice)
      len = bytes.size
      while len > 0 && bytes[len - 1] == 0
        len -= 1
      end
      String.new(bytes.to_unsafe, len)
    end

    def read_section?(name)
      if sh = sections.find { |s| s.sectname == name }
        @io.seek(sh.offset) do
          yield sh, @io
        end
      end
    end
  end
end

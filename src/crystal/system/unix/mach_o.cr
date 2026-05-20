require "c/fcntl"
require "c/sys/mman"
require "c/sys/stat"

class Crystal::System::MachO
  lib LibMachO
    MAGIC_64      = 0xfeedfacf_u32
    LC_SEGMENT_64 =           0x19
    LC_UUID       =           0x1b

    struct Header
      magic : UInt32
      cputype : UInt32
      cpusubtype : UInt32
      filetype : UInt32
      ncmds : UInt32
      sizeofcmds : UInt32
      flags : UInt32
      {% if flag?(:bits64) %}
        reserved : UInt32
      {% end %}
    end

    struct LoadCommand
      cmd : UInt32
      cmdsize : UInt32
    end

    struct UUIDCommand
      cmd : UInt32
      cmdsize : UInt32
      uuid : UInt8[16]
    end

    struct SegmentCommand64
      cmd : UInt32
      cmdsize : UInt32
      segname : UInt8[16]
      vmaddr : UInt64
      vmsize : UInt64
      fileoff : UInt64
      filesize : UInt64
      maxprot : UInt32
      initprot : UInt32
      nsects : UInt32
      flags : UInt32
    end

    struct Section64
      sectname : UInt8[16]
      segname : UInt8[16]
      addr : UInt64
      size : UInt64
      offset : UInt32
      align : UInt32
      reloff : UInt32
      nreloc : UInt32
      flags : UInt32
      reserved1 : UInt32
      reserved2 : UInt32
      reserved3 : UInt32
    end
  end

  def self.open(path : String, &)
    fd = LibC.open(path, LibC::O_RDONLY | LibC::O_CLOEXEC, 0)
    return if fd == -1

    begin
      return unless LibC.fstat(fd, out stat) == 0

      pointer = LibC.mmap(nil, stat.st_size, LibC::PROT_READ, LibC::MAP_PRIVATE, fd, 0)
      return if pointer == LibC::MAP_FAILED

      begin
        program = new(pointer.as(UInt8*), stat.st_size)
        yield program if program.valid?
      ensure
        LibC.munmap(pointer, stat.st_size)
      end
    ensure
      LibC.close(fd)
    end
  end

  def initialize(@pointer : UInt8*, @size : LibC::OffT)
  end

  # The file is a Mach-O file for the current architecture.
  def valid? : Bool
    header.value.magic == LibMachO::MAGIC_64
  end

  def uuid : StaticArray(UInt8, 16)?
    each_load_command(LibMachO::LC_UUID) do |load_command|
      return load_command.as(LibMachO::UUIDCommand*).value.uuid
    end
  end

  def section?(name : String, &)
    each_load_command(LibMachO::LC_SEGMENT_64) do |load_command|
      segment_command = load_command.as(LibMachO::SegmentCommand64*)
      section = (segment_command + 1).as(LibMachO::Section64*)

      segment_command.value.nsects.times do
        if name_equal?(name, section.value.sectname.to_unsafe)
          bytes = Bytes.new(@pointer + section.value.offset, section.value.size)
          return yield bytes, section.value.offset.to_i64
        end
        section += 1
      end
    end
  end

  private def each_load_command(cmd, &)
    ptr = @pointer + sizeof(LibMachO::Header)

    header.value.ncmds.times do
      load_command = ptr.as(LibMachO::LoadCommand*)
      yield load_command if load_command.value.cmd == cmd
      ptr += load_command.value.cmdsize
    end
  end

  private def name_equal?(name : String, pointer : UInt8*) : Bool
    return false if name.bytesize > 16

    name.to_slice.each do |byte|
      return false if pointer.value == 0_u8 || pointer.value != byte
      pointer += 1
    end
    pointer.value == 0_u8
  end

  private def header
    @pointer.as(LibMachO::Header*)
  end
end

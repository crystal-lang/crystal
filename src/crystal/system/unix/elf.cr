require "c/fcntl"
require "c/sys/mman"
require "c/sys/stat"

class Crystal::System::ELF
  lib LibELF
    {% if flag?(:bits64) %}
      alias ULong = UInt64
    {% else %}
      alias ULong = UInt32
    {% end %}

    MAGIC         = "\u{7f}ELF"
    CLASS_32      = 1
    CLASS_64      = 2
    ENDIAN_LITTLE = 1
    ENDIAN_BIG    = 2

    struct Header
      ei_magic : UInt8[4]
      ei_class : UInt8
      ei_data : UInt8
      ei_version : UInt8
      ei_osabi : UInt8
      ei_abiversion : UInt8
      ei_padding : UInt8[7]
      e_type : UInt16
      e_machine : UInt16
      e_version : UInt32
      e_entry : ULong
      e_phoff : ULong
      e_shoff : ULong
      e_flags : UInt32
      e_ehsize : UInt16
      e_phentsize : UInt16
      e_phnum : UInt16
      e_shentsize : UInt16
      e_shnum : UInt16
      e_shstrndx : UInt16
    end

    struct SectionHeader
      sh_name : UInt32
      sh_type : UInt32
      sh_flags : ULong
      sh_addr : ULong
      sh_offset : ULong
      sh_size : ULong
      sh_link : UInt32
      sh_info : UInt32
      sh_addralign : ULong
      sh_entsize : ULong
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

  # The file is an ELF file for the current architecture.
  def valid? : Bool
    header.value.ei_magic.to_slice == LibELF::MAGIC.to_slice &&
      header.value.ei_class == {% if flag?(:bits64) %} LibELF::CLASS_64 {% else %} LibELF::CLASS_32 {% end %} &&
      header.value.ei_data == {% if IO::ByteFormat::SystemEndian == IO::ByteFormat::BigEndian %} LibELF::ENDIAN_BIG {% else %} LibELF::ENDIAN_LITTLE {% end %} &&
      header.value.ei_version == 1 &&
      header.value.e_version == 1 &&
      header.value.e_ehsize == sizeof(LibELF::Header)
  end

  def section?(name : String, &)
    sh = (@pointer + header.value.e_shoff).as(LibELF::SectionHeader*)
    sh_name_offset = @pointer + (sh + header.value.e_shstrndx).value.sh_offset

    header.value.e_shnum.times do |i|
      if name_equal?(name, sh_name_offset + sh.value.sh_name)
        bytes = Bytes.new(@pointer + sh.value.sh_offset, sh.value.sh_size)
        return yield bytes, sh.value.sh_offset.to_i64
      end
      sh += 1
    end
  end

  private def name_equal?(name : String, pointer : UInt8*) : Bool
    name.to_slice.each do |byte|
      return false if pointer.value == 0_u8 || pointer.value != byte
      pointer += 1
    end
    pointer.value == 0_u8
  end

  private def header
    @pointer.as(LibELF::Header*)
  end
end

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

    ET_DYN = 3

    SHN_UNDEF  =      0
    SHN_XINDEX = 0xffff

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

  def self.open(path : String) : self?
    fd = LibC.open(path, LibC::O_RDONLY | LibC::O_CLOEXEC, 0)
    return if fd == -1

    begin
      return unless LibC.fstat(fd, out stat) == 0

      # FIXME: round stat.st_size to next page size to avoid SIGBUS errors

      pointer = LibC.mmap(nil, stat.st_size, LibC::PROT_READ, LibC::MAP_PRIVATE, fd, 0)
      return if pointer == LibC::MAP_FAILED

      program = new(pointer.as(UInt8*), stat.st_size)
      unless program.valid?
        program.close
        return
      end

      program
    ensure
      # we map the whole executable then return slices to each section, we don't
      # need the fd anymore and can close it early
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

  def pie?
    header.value.e_type == LibELF::ET_DYN
  end

  def section?(name : String, &)
    sh_pointer = @pointer + header.value.e_shoff

    e_shnum = header.value.e_shnum
    e_shstrndx = header.value.e_shstrndx

    if e_shnum == LibELF::SHN_UNDEF && e_shstrndx == LibELF::SHN_XINDEX
      # extended sections: values don't fit in the ELF header, they're in
      # section #0 (reserved)
      sh_0 = sh_pointer.as(LibELF::SectionHeader*)
      e_shnum = sh_0.value.sh_size
      e_shstrndx = sh_0.value.sh_link
    end

    sh_str = (sh_pointer + e_shstrndx.to_u64 * header.value.e_shentsize).as(LibELF::SectionHeader*)
    sh_names = @pointer + sh_str.value.sh_offset

    e_shnum.times do |i|
      sh = sh_pointer.as(LibELF::SectionHeader*)
      sh_name = sh_names + sh.value.sh_name

      if name_equal?(name, sh_name)
        bytes = Bytes.new(@pointer + sh.value.sh_offset, sh.value.sh_size)
        return yield bytes, sh.value.sh_offset.to_i64
      end

      sh_pointer += header.value.e_shentsize
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

  def close : Nil
    LibC.munmap(@pointer, @size)
  end
end

lib LibC
  MAP_FAILED = Pointer(Void).new(SizeT.new(-1))

  fun mmap(addr : Void*, len : SizeT, prot : Int, flags : Int, fd : Int, offset : SSizeT) : Void*
  fun munmap(addr : Void*, len : SizeT) : Int
  fun madvise(addr : Void*, length : SizeT, advice : Int) : Int
  fun msync(addr : Void*, length : SizeT, flags : Int) : Int
end

class Mmap(T)
  @[Flags]
  enum Prot
    None = 0x00
    Read = 0x01
    Write = 0x02
    Exec = 0x04
    ReadWrite = Read | Write
  end

  ifdef darwin
    @[Flags]
    enum Flags
      Shared = 0x0001
      Private = 0x0002
      Anon = 0x1000
      Default = Private | Anon
    end
  elsif linux
    @[Flags]
    enum Flags
      Shared = 0x0001
      Private = 0x0002
      Anon = 0x0020
      Default = Private | Anon
    end
  end

  getter size

  def self.open addr = nil, size = 0, prot = Prot::ReadWrite, flags = Flags::Default, fd = -1, offset = 0
    mmap = new addr, size, prot, flags, fd, offset
    begin
      yield mmap
    ensure
      mmap.close
    end
  end

  # size is specified in the number of T's or bytes for Void.
  def initialize addr = nil, @size = 0, prot = Prot::ReadWrite, flags = Flags::Default, fd = -1, offset = 0
    ret = LibC.mmap(addr, bytesize, prot, flags, fd, offset)
    raise Errno.new("mmap") if ret == LibC::MAP_FAILED
    @pointer = ret as Pointer(T)
  end

  # Gets the value pointed at this pointer's address plus `offset * sizeof(T)`.
  def [](offset) : T
    dst = pointer_offset offset
    dst.value
  end

  # Returns a `Slice(T)` that points to this pointer and is bounded by the given *length*.
  def [](offset, length) : Slice(T)
    dst = pointer_offset offset
    Slice(T).new dst, length
  end

  # Sets the value pointed at this pointer's address plus `offset * sizeof(T)`.
  def []=(offset, val : T) : T
    dst = pointer_offset offset
    src = pointerof(val)
    dst.copy_from src, 1
    val
  end

  # Copies *slice.count* elements from *slice* into *self*.
  def []= offset, slice : Slice(T)
    dst = pointer_offset offset, slice.size
    slice.copy_to dst, slice.size
    slice
  end

  def bytesize
    sizeof(T) * @size
  end

  # See POSIX madvise()
  def advise offset, length, advice
    dst = pointer_offset offset, length
    if LibC.madvise(dst, length, advice) != 0
      raise Errno.new("madvise")
    end
    nil
  end

  # See POSIX msync()
  def sync offset, length, flags
    dst = pointer_offset offset, length
    if LibC.madvise(dst, length, flags) != 0
      raise Errno.new("msync")
    end
    nil
  end

  # After closing all slices and pointers referencing the mmap'd area will be inaccessible.
  def close
    ptr = @pointer
    return if ptr.null?

    if LibC.munmap(ptr as Pointer(Void), bytesize) != 0
      raise Errno.new("munmap")
    end
    @pointer = Pointer(T).null
    @size = 0
    nil
  end

  def to_unsafe
    @pointer
  end

  def finalize
    close
  end

  private def pointer_offset offset, length = 1
    if offset + length > @size
      raise ArgumentError.new("copy would extend out of mapped memory offset=#{offset} length=#{length} mmap_size=#{@size}")
    end

    @pointer + offset
  end
end

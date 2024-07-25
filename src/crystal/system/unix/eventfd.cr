require "c/sys/eventfd"

struct Crystal::System::EventFD
  # NOTE: no need to concern ourselves with endianness: we interpret the bytes
  # in the system order and eventfd can only be used locally (no cross system
  # issues).

  getter fd : Int32

  def initialize(value = 0)
    @fd = LibC.eventfd(value, LibC::EFD_CLOEXEC)
    raise RuntimeError.from_errno("eventfd") if @fd == -1
  end

  def read : UInt64
    buf = uninitialized UInt8[8]
    bytes_read = LibC.read(@fd, buf.to_unsafe, buf.size)
    raise RuntimeError.from_errno("eventfd_read") unless bytes_read == 8
    buf.unsafe_as(UInt64)
  end

  def write(value : UInt64) : Nil
    buf = value.unsafe_as(StaticArray(UInt8, 8))
    bytes_written = LibC.write(@fd, buf.to_unsafe, buf.size)
    raise RuntimeError.from_errno("eventfd_write") unless bytes_written == 8
  end

  def close : Nil
    LibC.close(@fd)
  end
end

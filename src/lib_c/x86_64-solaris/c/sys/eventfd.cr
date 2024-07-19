lib LibC
  EFD_CLOEXEC = 0o2000000

  alias EventfdT = UInt64

  fun eventfd(count : UInt, flags : Int) : Int
  fun eventfd_read(fd : Int, value : EventfdT*) : Int
  fun eventfd_write(fd : Int, value : EventfdT) : Int
end

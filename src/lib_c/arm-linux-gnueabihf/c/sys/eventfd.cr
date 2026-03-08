lib LibC
  EFD_CLOEXEC = 0o2000000

  fun eventfd(count : UInt, flags : Int) : Int
end

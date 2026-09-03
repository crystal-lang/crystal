lib LibC
  GRND_NONBLOCK = 1_u32

  fun getrandom(buf : Void*, buflen : SizeT, flags : UInt32) : SSizeT
end

lib LibC
  TCGETS  = 0x5401
  TCSETS  = 0x5402
  TCSETSW = 0x5403
  TCSETSF = 0x5404

  fun ioctl(__fd : Int, __request : Int, ...) : Int
end

require "./stddef"

lib LibC
  type IconvT = Void*

  fun iconv(x0 : IconvT, x1 : Char**, x2 : SizeT*, x3 : Char**, x4 : SizeT*) : SizeT
  fun iconv_close(x0 : IconvT) : Int
  fun iconv_open(x0 : Char*, x1 : Char*) : IconvT

  ICONV_F_HIDE_INVALID = 0x0001
  fun __iconv(x0 : IconvT, x1 : Char**, x2 : SizeT*, x3 : Char**, x4 : SizeT*, flags : UInt32, invalids : SizeT*) : SizeT
end

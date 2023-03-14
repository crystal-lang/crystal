require "./stddef"

lib LibC
  type IconvT = Void*

  # Although FreeBSD libc provides iconv_XXXX functions, they are just compatibility symbols,
  # not directly visible via dlsym(3). Use FreeBSD-specific exported symbols so iconv also
  # works in the interpreter.
  fun iconv = __bsd_iconv(x0 : IconvT, x1 : Char**, x2 : SizeT*, x3 : Char**, x4 : SizeT*) : SizeT
  fun iconv_close = __bsd_iconv_close(x0 : IconvT) : Int
  fun iconv_open = __bsd_iconv_open(x0 : Char*, x1 : Char*) : IconvT

  ICONV_F_HIDE_INVALID = 0x0001
  fun __iconv = __bsd___iconv(x0 : IconvT, x1 : Char**, x2 : SizeT*, x3 : Char**, x4 : SizeT*, flags : UInt32, invalids : SizeT*) : SizeT
end

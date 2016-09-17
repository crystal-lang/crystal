require "./stddef"

@[Link("iconv")]
lib LibC
  type IconvT = Void*

  fun iconv = libiconv(x0 : IconvT, x1 : Char**, x2 : SizeT*, x3 : Char**, x4 : SizeT*) : SizeT
  fun iconv_close = libiconv_close(x0 : IconvT) : Int
  fun iconv_open = libiconv_open(x0 : Char*, x1 : Char*) : IconvT
end

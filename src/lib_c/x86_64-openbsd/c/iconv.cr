require "./stddef"

@[Link("iconv")]
lib LibC
  type IconvT = Void*

  fun iconv = libiconv(cd : IconvT, inbuf : Char**, inbytesleft : SizeT*, outbuf : Char**, outbytesleft : SizeT*) : SizeT
  fun iconv_close = libiconv_close(cd : IconvT) : Int
  fun iconv_open = libiconv_open(tocode : Char*, fromcode : Char*) : IconvT
end

require "./stddef"

lib LibC
  type IconvT = Void*

  fun iconv(cd : IconvT, inbuf : Char**, inbytesleft : SizeT*, outbuf : Char**, outbytesleft : SizeT*) : SizeT
  fun iconv_close(cd : IconvT) : Int
  fun iconv_open(tocode : Char*, fromcode : Char*) : IconvT
end

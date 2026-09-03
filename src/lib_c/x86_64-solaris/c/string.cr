require "./stddef"

lib LibC
  fun memchr(x0 : Void*, c : Int, n : SizeT) : Void*
  fun memcmp(x0 : Void*, x1 : Void*, x2 : SizeT) : Int
  fun strcmp(x0 : Char*, x1 : Char*) : Int
  fun strerror(x0 : Int) : Char*
  fun strerror_r(Int, Char*, SizeT) : Int
  fun strlen(x0 : Char*) : SizeT
end

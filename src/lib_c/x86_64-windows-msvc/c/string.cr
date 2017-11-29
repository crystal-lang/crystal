require "./stddef"

lib LibC
  fun memchr(x0 : Void*, c : Int, n : SizeT) : Void*
  fun memcmp(s1 : Void*, s2 : Void*, n : SizeT) : Int
  fun strcmp(s1 : Char*, s2 : Char*) : Int
  fun strerror(errnum : Int) : Char*
  fun strlen(s : Char*) : SizeT
end

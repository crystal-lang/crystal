require "./stddef"

lib LibC
  fun memchr(b : Void*, c : Int, len : SizeT) : Void*
  fun memcmp(b1 : Void*, b2 : Void*, len : SizeT) : Int
  fun strcmp(s1 : Char*, s2 : Char*) : Int
  fun strncmp(s1 : Char*, s2 : Char*, len : SizeT) : Int
  fun strerror(errnum : Int) : Char*
  fun strlen(s : Char*) : SizeT
  fun strnlen(s : Char*, maxlen SizeT) : SizeT
  fun explicit_bzero(b : Void*, len : SizeT) : Void
end

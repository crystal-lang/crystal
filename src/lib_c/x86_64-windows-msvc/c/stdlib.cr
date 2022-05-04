require "./stddef"

lib LibC
  fun exit(status : Int) : NoReturn
  fun _exit(status : Int) : NoReturn
  fun free(ptr : Void*) : Void
  fun malloc(size : SizeT) : Void*
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun strtof(nptr : Char*, endptr : Char**) : Float
  fun strtod(nptr : Char*, endptr : Char**) : Double
end

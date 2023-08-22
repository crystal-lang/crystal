require "./stddef"

lib LibC
  struct DivT
    quot : Int
    rem : Int
  end

  fun atof(nptr : Char*) : Double
  fun div(numer : Int, denom : Int) : DivT
  fun exit(status : Int) : NoReturn
  fun _exit(status : Int) : NoReturn
  fun free(ptr : Void*) : Void
  fun malloc(size : SizeT) : Void*
  fun putenv(string : Char*) : Int
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun strtof(nptr : Char*, endptr : Char**) : Float
  fun strtod(nptr : Char*, endptr : Char**) : Double
end

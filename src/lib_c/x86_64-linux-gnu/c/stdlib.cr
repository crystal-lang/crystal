require "./stddef"
require "./sys/wait"

lib LibC
  struct DivT
    quot : Int
    rem : Int
  end

  fun atof(nptr : Char*) : Double
  fun div(numer : Int, denom : Int) : DivT
  fun exit(status : Int) : NoReturn
  fun free(ptr : Void*) : Void
  fun getenv(name : Char*) : Char*
  fun malloc(size : SizeT) : Void*
  fun mkstemp(template : Char*) : Int
  fun mkstemps(template : Char*, suffixlen : Int) : Int
  fun putenv(string : Char*) : Int
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun realpath(name : Char*, resolved : Char*) : Char*
  fun setenv(name : Char*, value : Char*, replace : Int) : Int
  fun strtof(nptr : Char*, endptr : Char**) : Float
  fun strtod(nptr : Char*, endptr : Char**) : Double
  fun unsetenv(name : Char*) : Int
end

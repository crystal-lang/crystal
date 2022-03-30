require "./stddef"
require "./sys/wait"

lib LibC
  fun exit(status : Int) : NoReturn
  fun free(ptr : Void*) : Void
  fun getenv(name : Char*) : Char*
  fun malloc(size : SizeT) : Void*
  fun mkstemp(template : Char*) : Int
  fun mkstemps(template : Char*, suffixlen : Int) : Int
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun realpath(name : Char*, resolved : Char*) : Char*
  fun setenv(name : Char*, value : Char*, replace : Int) : Int
  fun strtod(nptr : Char*, endptr : Char**) : Double
  fun strtof(nptr : Char*, endptr : Char**) : Float
  fun strtol(nptr : Char*, endptr : Char**, base : Int) : Long
  fun unsetenv(name : Char*) : Int
end

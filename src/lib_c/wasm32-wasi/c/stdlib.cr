require "./stddef"

lib LibC
  fun arc4random : UInt32T
  fun arc4random_buf(x0 : Void*, x1 : SizeT) : Void
  fun arc4random_uniform(x0 : UInt32T) : UInt32T
  fun exit(x0 : Int) : NoReturn
  fun free(ptr : Void*) : Void
  fun getenv(x0 : Char*) : Char*
  fun malloc(size : SizeT) : Void*
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun setenv(x0 : Char*, x1 : Char*, x2 : Int) : Int
  fun strtod(x0 : Char*, x1 : Char**) : Double
  fun strtof(x0 : Char*, x1 : Char**) : Float
  fun strtol(x0 : Char*, x1 : Char**, x2 : Int) : Long
  fun unsetenv(x0 : Char*) : Int
end

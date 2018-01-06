require "./stddef"
require "./sys/wait"

lib LibC
  struct DivT
    quot : Int  # quotient
    rem : Int   # remainder
  end

  fun atof(x0 : Char*) : Double
  fun div(x0 : Int, x1 : Int) : DivT
  fun exit(x0 : Int) : NoReturn
  fun free(x0 : Void*) : Void
  fun getenv(x0 : Char*) : Char*
  fun calloc(x0 : SizeT, x0 : SizeT) : Void*
  fun malloc(x0 : SizeT) : Void*
  fun reallocarray(x0 : Void*, x1 : SizeT, x2 : SizeT) : Void*
  fun recallocarray(x0 : Void*, x1 : SizeT, x2 : SizeT, x3 : SizeT) : Void*
  fun realloc(x0 : Void*, x1 : SizeT) : Void*
  fun strtod(x0 : Char*, x1 : Char**) : Double
  fun strtof(x0 : Char*, x1 : Char**) : Float
  fun putenv(x0 : Char*) : Int
  fun realpath(x0 : Char*, x1 : Char*) : Char*
  fun mkstemp(x0 : Char*) : Int
  fun setenv(x0 : Char*, x1 : Char*, x2 : Int) : Int
  fun unsetenv(x0 : Char*) : Int
  fun mkstemps(x0 : Char*, x1 : Int) : Int

  fun arc4random : UInt32
  fun arc4random_uniform(upper_bound : UInt32) : UInt32
  fun arc4random_buf(x0 : Void*, x1 : SizeT) : Void
end

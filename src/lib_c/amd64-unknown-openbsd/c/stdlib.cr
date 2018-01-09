require "./stddef"
require "./sys/wait"

lib LibC
  struct DivT
    quot : Int # quotient
    rem : Int  # remainder
  end

  fun atof(nptr : Char*) : Double
  fun div(num : Int, denom : Int) : DivT
  fun exit(status : Int) : NoReturn
  fun free(ptr : Void*) : Void
  fun getenv(name : Char*) : Char*
  fun calloc(nmemb : SizeT, size : SizeT) : Void*
  fun malloc(size : SizeT) : Void*
  fun reallocarray(ptr : Void*, nmemb : SizeT, size : SizeT) : Void*
  fun recallocarray(ptr : Void*, oldnmemb : SizeT, nmemb : SizeT, size : SizeT) : Void*
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun strtod(nptr : Char*, endptr : Char**) : Double
  fun strtof(nptr : Char*, endptr : Char**) : Float
  fun putenv(string : Char*) : Int
  fun realpath(pathname : Char*, resolved : Char*) : Char*
  fun mkstemp(template : Char*) : Int
  fun setenv(name : Char*, value : Char*, overwrite : Int) : Int
  fun unsetenv(name : Char*) : Int
  fun mkstemps(template : Char*, suffixlen : Int) : Int

  fun arc4random : UInt32
  fun arc4random_uniform(upper_bound : UInt32) : UInt32
  fun arc4random_buf(buf : Void*, nbytes : SizeT) : Void
end

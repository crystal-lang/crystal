require "./stddef"
require "./sys/wait"

lib LibC
  fun exit(__status : Int) : NoReturn
  fun free(__ptr : Void*)
  fun getenv(__name : Char*) : Char*
  fun malloc(__byte_count : SizeT) : Void*
  fun mkstemp(__template : Char*) : Int
  fun mkstemps(__template : Char*, __flags : Int) : Int
  fun putenv(__assignment : Char*) : Int
  fun realloc(__ptr : Void*, __byte_count : SizeT) : Void*
  fun realpath(__path : Char*, __resolved : Char*) : Char*
  fun setenv(__name : Char*, __value : Char*, __overwrite : Int) : Int
  fun strtod(__s : Char*, __end_ptr : Char**) : Double
  {% if ANDROID_API >= 21 %}
    # TODO: defined inline for `ANDROID_API < 21`
    fun strtof(__s : Char*, __end_ptr : Char**) : Float
  {% end %}
  fun unsetenv(__name : Char*) : Int
end

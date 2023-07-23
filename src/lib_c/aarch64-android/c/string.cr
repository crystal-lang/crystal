require "./stddef"

lib LibC
  fun memchr(__s : Void*, __ch : Int, __n : SizeT) : Void*
  fun memcmp(__lhs : Void*, __rhs : Void*, __n : SizeT) : Int
  fun strcmp(__lhs : Char*, __rhs : Char*) : Int
  fun strerror(__errno_value : Int) : Char*
  fun strlen(__s : Char*) : SizeT
end

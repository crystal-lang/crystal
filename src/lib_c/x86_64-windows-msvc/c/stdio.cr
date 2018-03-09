require "./stddef"

lib LibC
  fun printf(format : Char*, ...) : Int
  fun rename(old : Char*, new : Char*) : Int
  fun vsnprintf(str : Char*, size : SizeT, format : Char*, ap : VaList) : Int
  fun snprintf = __crystal_snprintf(str : Char*, size : SizeT, format : Char*, ...) : Int
end

fun __crystal_snprintf(str : LibC::Char*, size : LibC::SizeT, format : LibC::Char*, ...) : LibC::Int
  VaList.open do |varargs|
    LibC.vsnprintf(str, size, format, varargs)
  end
end

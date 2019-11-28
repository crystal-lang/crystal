require "./stddef"

@[Link("legacy_stdio_definitions")]
lib LibC
  fun printf(format : Char*, ...) : Int
  fun rename(old : Char*, new : Char*) : Int
  fun vsnprintf(str : Char*, size : SizeT, format : Char*, ap : VaList) : Int
  fun vfprintf(stream : Void*, format : Char*, ap : VaList) : Int
  fun snprintf = __crystal_snprintf(str : Char*, size : SizeT, format : Char*, ...) : Int
  fun dprintf = __crystal_dprintf(fd : Int, format : Char*, ...) : Int
  fun _fdopen(fd : Int, mode : Char*) : Void*
  fun fclose(stream : Void*) : Int
  fun fflush(stream : Void*) : Int
end

fun __crystal_dprintf(fd : LibC::Int, format : LibC::Char*, ...) : LibC::Int
  f = LibC._fdopen(fd, "w")
  if f == LibC::NULL
    return -1
  end
  res : LibC::Int = 0
  VaList.open do |varargs|
    res = LibC.vfprintf(f, format, varargs)
  end
  LibC.fflush(f)
  res
end

fun __crystal_snprintf(str : LibC::Char*, size : LibC::SizeT, format : LibC::Char*, ...) : LibC::Int
  VaList.open do |varargs|
    LibC.vsnprintf(str, size, format, varargs)
  end
end

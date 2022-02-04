require "./stddef"

@[Link("legacy_stdio_definitions")]
lib LibC
  fun printf(format : Char*, ...) : Int
  fun rename(old : Char*, new : Char*) : Int
  fun snprintf(buffer : Char*, count : SizeT, format : Char*, ...) : Int
end

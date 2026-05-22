lib LibC
  fun dprintf(fd : Int32, format : UInt8*, ...) : Int32
  fun exit(code : Int32) : NoReturn
end

class String
  def to_unsafe
    pointerof(@c)
  end
end

i = 1
while i < ARGC_UNSAFE
  LibC.dprintf(1, " ") unless i == 1
  LibC.dprintf(1, "%s", (ARGV_UNSAFE + i).value)
  i &+= 1
end

LibC.exit(0)

lib LibC
  fun write(fd : Int32, buf : Void*, count : UInt32) : Int32
  fun exit(code : Int32) : NoReturn
end

s = "hello world\n"
ret = LibC.write(1, pointerof(s.@c), s.@length)
LibC.exit(s.@length &- ret)

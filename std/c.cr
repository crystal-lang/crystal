lib C
  fun rand : Int32
  fun srand(seed : UInt32)
  fun time(t : Int64) : Int64
  fun fork : Int32
  fun exit(status : Int32) : NoReturn
  fun sleep(seconds : UInt32) : UInt32
end

def exit(status = 0)
  C.exit status
end

def sleep(seconds)
  C.sleep seconds.to_u32
end

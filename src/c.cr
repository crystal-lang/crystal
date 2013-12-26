lib C
  ifdef x86_64
    alias SizeT = UInt64
  else
    alias SizeT = UInt32
  end

  fun time(t : Int64) : Int64
  fun sleep(seconds : UInt32) : UInt32
end

def exit(status = 0)
  Process.exit(status)
end

def sleep(seconds)
  C.sleep seconds.to_u32
end

def fork
  Process.fork { yield }
end

def fork()
  Process.fork()
end

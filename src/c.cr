lib C
  ifdef darwin
    alias ModeT = UInt16
  elsif linux
    alias ModeT = UInt32
  end

  ifdef x86_64
    alias SizeT = UInt64
    alias TimeT = Int64
  else
    alias SizeT = UInt32
    alias TimeT = Int32
  end

  fun time(t : Int64) : Int64
  fun sleep(seconds : UInt32) : UInt32
  fun free(ptr : Void*)
end

def exit(status = 0)
  Process.exit(status)
end

def abort(message, status = 1)
  puts message
  exit status
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

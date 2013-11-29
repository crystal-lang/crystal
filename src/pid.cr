lib C
  fun getpid : Int32
  fun getppid : Int32
end

PID = C.getpid
PPID = C.getppid

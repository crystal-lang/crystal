lib LibC
  fun getpid : Int32
  fun getppid : Int32
end

PID = LibC.getpid
PPID = LibC.getppid

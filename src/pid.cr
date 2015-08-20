lib LibC
  fun getpid : PidT
  fun getppid : PidT
end

PID = LibC.getpid
PPID = LibC.getppid

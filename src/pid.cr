lib LibC
  ifdef darwin || linux
    fun getpid : Int32
    fun getppid : Int32
  elsif windows
    fun getpid = _getpid : Int32
  end
end

PID = LibC.getpid
ifdef darwin || linux
  PPID = LibC.getppid
elsif windows
  PPID = 0
end

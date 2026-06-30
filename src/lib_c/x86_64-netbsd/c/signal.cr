require "./sys/types"
require "./time"

lib LibC
  SIGHUP    = 1
  SIGINT    = 2
  SIGQUIT   = 3
  SIGILL    = 4
  SIGTRAP   = 5
  SIGIOT    = LibC::SIGABRT
  SIGABRT   =  6
  SIGEMT    =  7
  SIGFPE    =  8
  SIGKILL   =  9
  SIGBUS    = 10
  SIGSEGV   = 11
  SIGSYS    = 12
  SIGPIPE   = 13
  SIGALRM   = 14
  SIGTERM   = 15
  SIGURG    = 16
  SIGSTOP   = 17
  SIGTSTP   = 18
  SIGCONT   = 19
  SIGCHLD   = 20
  SIGTTIN   = 21
  SIGTTOU   = 22
  SIGIO     = 23
  SIGXCPU   = 24
  SIGXFSZ   = 25
  SIGVTALRM = 26
  SIGUSR1   = 30
  SIGUSR2   = 31
  SIGINFO   = 29
  SIGWINCH  = 28

  SIGSTKSZ = 40960

  SIG_SETMASK = 3

  alias SighandlerT = Int ->
  SIG_DFL = SighandlerT.new(Pointer(Void).new(0_u64), Pointer(Void).null)
  SIG_IGN = SighandlerT.new(Pointer(Void).new(1_u64), Pointer(Void).null)

  struct SigsetT
    bits : UInt32[4]
  end

  CLD_EXITED = 1

  SA_ONSTACK = 0x0001
  SA_RESTART = 0x0002
  SA_SIGINFO = 0x0040

  struct SiginfoT___reason___child
    _pid : PidT
    _uid : UidT
    _status : Int
    _utime : ClockT
    _stime : ClockT
  end

  struct SiginfoT___reason___fault
    _addr : Void*
    _trap : Int
    _trap2 : Int
    _trap3 : Int
  end

  union SiginfoT___reason
    _child : SiginfoT___reason___child
    _fault : SiginfoT___reason___fault
    _pad : Char[112]
  end

  struct SiginfoT
    si_signo : Int
    si_code : Int
    si_errno : Int
    _pad1 : Int
    _reason : SiginfoT___reason
  end

  alias SigactionHandlerT = (Int, SiginfoT*, Void*) ->

  struct Sigaction
    # Technically a union, but only one can be valid and we only use sa_sigaction
    # and not sa_handler (which would be a SighandlerT)
    sa_sigaction : SigactionHandlerT
    sa_flags : Int
    sa_mask : SigsetT
  end

  struct StackT
    ss_sp : Void*
    ss_size : SizeT
    ss_flags : Int
  end

  fun kill(x0 : PidT, x1 : Int) : Int
  fun pthread_sigmask(Int, SigsetT*, SigsetT*) : Int
  fun pthread_kill(PthreadT, Int) : Int
  fun signal(x0 : Int, x1 : Int -> Void) : Int -> Void
  fun sigaction = __sigaction14(x0 : Int, x1 : Sigaction*, x2 : Sigaction*) : Int
  fun sigaltstack = __sigaltstack14(x0 : StackT*, x1 : StackT*) : Int
  fun sigemptyset = __sigemptyset14(SigsetT*) : Int
  fun sigfillset = __sigfillset14(SigsetT*) : Int
  fun sigaddset = __sigaddset14(SigsetT*, Int) : Int
  fun sigdelset = __sigdelset14(SigsetT*, Int) : Int
  fun sigismember = __sigismember14(SigsetT*, Int) : Int
  fun sigsuspend(SigsetT*) : Int
end

struct LibC::SiginfoT
  def si_addr : Void*
    _reason._fault._addr
  end

  def si_addr=(si_addr : Void*)
    _reason._fault._addr = si_addr
  end

  def si_pid : PidT
    _reason._child._pid
  end

  def si_status : Int
    _reason._child._status
  end
end

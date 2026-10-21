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
  SIGEMT    =  7
  SIGINFO   = 29
  SIGWINCH  = 28

  MAX_PAGE_SHIFT = 12_u32
  MINSIGSTKSZ    = 3_u64 << LibC::MAX_PAGE_SHIFT
  SIGSTKSZ       = LibC::MINSIGSTKSZ + (1_u64 << LibC::MAX_PAGE_SHIFT) * 4

  SIG_SETMASK = 3

  alias SighandlerT = Int ->
  alias SigsetT = UInt32

  SIG_DFL = SighandlerT.new(Pointer(Void).new(0_u64), Pointer(Void).null)
  SIG_IGN = SighandlerT.new(Pointer(Void).new(1_u64), Pointer(Void).null)

  CLD_EXITED = 1

  SA_ONSTACK = 0x0001
  SA_RESTART = 0x0002
  SA_SIGINFO = 0x0040

  struct SiginfoT___data___proc___pdata___cld
    _utime : ClockT
    _stime : ClockT
    _status : Int
  end

  union SiginfoT___data___proc___pdata
    # _kill : omitted
    _cld : SiginfoT___data___proc___pdata___cld
  end

  struct SiginfoT___data___proc
    _pid : PidT
    _uid : UidT
    _pdata : SiginfoT___data___proc___pdata
  end

  struct SiginfoT___data___fault
    _addr : Void*
    _trapno : Int
  end

  union SiginfoT___data
    _pad : Int[29]
    _proc : SiginfoT___data___proc
    _fault : SiginfoT___data___fault
  end

  struct SiginfoT
    si_signo : Int
    si_code : Int
    si_errno : Int
    _data : SiginfoT___data
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
  fun sigaction(x0 : Int, x1 : Sigaction*, x2 : Sigaction*) : Int
  fun sigaltstack(x0 : StackT*, x1 : StackT*) : Int
  fun sigemptyset(SigsetT*) : Int
  fun sigfillset(SigsetT*) : Int
  fun sigaddset(SigsetT*, Int) : Int
  fun sigdelset(SigsetT*, Int) : Int
  fun sigismember(SigsetT*, Int) : Int
  fun sigsuspend(SigsetT*) : Int
end

struct LibC::SiginfoT
  def si_addr : Void*
    _data._fault._addr
  end

  def si_addr=(si_addr : Void*)
    _data._fault._addr = si_addr
  end

  def si_pid : PidT
    _data._proc._pid
  end

  def si_status : Int
    _data._proc._pdata._cld._status
  end
end

require "./sys/types"
require "./time"

lib LibC
  SIGHUP    =  1
  SIGINT    =  2
  SIGQUIT   =  3
  SIGILL    =  4
  SIGTRAP   =  5
  SIGIOT    =  6
  SIGABRT   =  6
  SIGFPE    =  8
  SIGKILL   =  9
  SIGBUS    =  7
  SIGSEGV   = 11
  SIGSYS    = 31
  SIGPIPE   = 13
  SIGALRM   = 14
  SIGTERM   = 15
  SIGURG    = 23
  SIGSTOP   = 19
  SIGTSTP   = 20
  SIGCONT   = 18
  SIGCHLD   = 17
  SIGCLD    = LibC::SIGCHLD
  SIGTTIN   = 21
  SIGTTOU   = 22
  SIGIO     = 29
  SIGXCPU   = 24
  SIGXFSZ   = 25
  SIGVTALRM = 26
  SIGUSR1   = 10
  SIGUSR2   = 12
  SIGWINCH  = 28
  SIGPWR    = 30
  SIGSTKFLT = 16
  SIGUNUSED = 31

  SIGSTKSZ = 8192

  SIG_SETMASK = 2

  alias SighandlerT = Int ->
  SIG_DFL = SighandlerT.new(Pointer(Void).new(0_u64), Pointer(Void).null)
  SIG_IGN = SighandlerT.new(Pointer(Void).new(1_u64), Pointer(Void).null)

  struct SigsetT
    val : ULong[32] # (1024 / (8 * sizeof(ULong)))
  end

  SA_ONSTACK = 0x08000000
  SA_SIGINFO = 0x00000004

  struct SiginfoT
    si_signo : Int
    si_errno : Int
    si_code : Int
    si_addr : Void*              # Assuming the sigfault form of siginfo_t
    __pad : StaticArray(Int, 27) # __SI_PAD_SIZE (29) - sizeof(void*) (4) = 25
  end

  alias SigactionHandlerT = (Int, SiginfoT*, Void*) ->

  struct Sigaction
    sa_sigaction : SigactionHandlerT
    sa_mask : SigsetT
    sa_flags : Int
    sa_restorer : ->
  end

  struct StackT
    ss_sp : Void*
    ss_flags : Int
    ss_size : SizeT
  end

  fun kill(pid : PidT, sig : Int) : Int
  fun pthread_sigmask(Int, SigsetT*, SigsetT*) : Int
  fun signal(sig : Int, handler : Int -> Void) : Int -> Void
  fun sigaction(x0 : Int, x1 : Sigaction*, x2 : Sigaction*) : Int
  fun sigaltstack(x0 : StackT*, x1 : StackT*) : Int
  fun sigemptyset(SigsetT*) : Int
  fun sigfillset(SigsetT*) : Int
  fun sigaddset(SigsetT*, Int) : Int
  fun sigdelset(SigsetT*, Int) : Int
  fun sigismember(SigsetT*, Int) : Int
end

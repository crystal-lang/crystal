require "./sys/types"
require "./time"

lib LibC
  SIGHUP     =  1
  SIGINT     =  2
  SIGQUIT    =  3
  SIGILL     =  4
  SIGTRAP    =  5
  SIGIOT     =  6
  SIGABRT    =  6
  SIGEMT     =  7
  SIGFPE     =  8
  SIGKILL    =  9
  SIGBUS     = 10
  SIGSEGV    = 11
  SIGSYS     = 12
  SIGPIPE    = 13
  SIGALRM    = 14
  SIGTERM    = 15
  SIGUSR1    = 16
  SIGUSR2    = 17
  SIGCLD     = 18
  SIGCHLD    = 18
  SIGPWR     = 19
  SIGWINCH   = 20
  SIGURG     = 21
  SIGPOLL    = 22
  SIGIO      = LibC::SIGPOLL
  SIGSTOP    = 23
  SIGTSTP    = 24
  SIGCONT    = 25
  SIGTTIN    = 26
  SIGTTOU    = 27
  SIGVTALRM  = 28
  SIGPROF    = 29
  SIGXCPU    = 30
  SIGXFSZ    = 31
  SIGWAITING = 32
  SIGLWP     = 33
  SIGFREEZE  = 34
  SIGTHAW    = 35
  SIGCANCEL  = 36
  SIGLOST    = 37
  SIGXRES    = 38
  SIGJVM1    = 39
  SIGJVM2    = 40
  SIGINFO    = 41

  SIGSTKSZ = 8192

  SIG_SETMASK = 3

  alias SighandlerT = Int ->
  SIG_DFL = SighandlerT.new(Pointer(Void).new(0_u64), Pointer(Void).null)
  SIG_IGN = SighandlerT.new(Pointer(Void).new(1_u64), Pointer(Void).null)

  struct SigsetT
    bits : UInt[4]
  end

  SA_ONSTACK = 0x00000001
  SA_RESTART = 0x00000004
  SA_SIGINFO = 0x00000008

  struct SiginfoT
    si_signo : Int
    si_code : Int
    si_errno : Int
    si_pad : Int
    si_addr : Void*
    __pad : Int[58] # SI_MAXSZ (256) / sizeof(int) - ...
  end

  alias SigactionHandlerT = (Int, SiginfoT*, Void*) ->

  struct Sigaction
    sa_flags : Int
    # Technically a union, but only one can be valid and we only use sa_sigaction
    # and not sa_handler (which would be a SighandlerT)
    sa_sigaction : SigactionHandlerT
    sa_mask : SigsetT
  end

  struct StackT
    ss_sp : Void*
    ss_size : SizeT
    ss_flags : Int
  end

  fun kill(x0 : PidT, x1 : Int) : Int
  fun pthread_sigmask(Int, SigsetT*, SigsetT*) : Int
  fun signal(x0 : Int, x1 : Int -> Void) : Int -> Void
  fun sigaction(x0 : Int, x1 : Sigaction*, x2 : Sigaction*) : Int
  fun sigaltstack(x0 : StackT*, x1 : StackT*) : Int
  fun sigemptyset(SigsetT*) : Int
  fun sigfillset(SigsetT*) : Int
  fun sigaddset(SigsetT*, Int) : Int
  fun sigdelset(SigsetT*, Int) : Int
  fun sigismember(SigsetT*, Int) : Int
end

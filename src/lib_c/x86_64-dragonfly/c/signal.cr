require "./sys/types"
require "./time"

lib LibC
  SIGHUP      = 1
  SIGINT      = 2
  SIGQUIT     = 3
  SIGILL      = 4
  SIGTRAP     = 5
  SIGIOT      = LibC::SIGABRT
  SIGABRT     =  6
  SIGEMT      =  7
  SIGFPE      =  8
  SIGKILL     =  9
  SIGBUS      = 10
  SIGSEGV     = 11
  SIGSYS      = 12
  SIGPIPE     = 13
  SIGALRM     = 14
  SIGTERM     = 15
  SIGURG      = 16
  SIGSTOP     = 17
  SIGTSTP     = 18
  SIGCONT     = 19
  SIGCHLD     = 20
  SIGTTIN     = 21
  SIGTTOU     = 22
  SIGIO       = 23
  SIGXCPU     = 24
  SIGXFSZ     = 25
  SIGVTALRM   = 26
  SIGPROF     = 27
  SIGWINCH    = 28
  SIGINFO     = 29
  SIGUSR1     = 30
  SIGUSR2     = 31
  SIGTHR      = 32
  SIGCKPT     = 33
  SIGCKPTEXIT = 34

  SIG_SETMASK = 3

  alias SighandlerT = Int ->
  SIG_DFL = SighandlerT.new(Pointer(Void).new(0_u64), Pointer(Void).null)
  SIG_IGN = SighandlerT.new(Pointer(Void).new(1_u64), Pointer(Void).null)

  struct SigsetT
    bits : UInt32[4]
  end

  fun kill(x0 : PidT, x1 : Int) : Int
  fun pthread_sigmask(Int, SigsetT*, SigsetT*) : Int
  fun signal(x0 : Int, x1 : Int -> Void) : Int -> Void
  fun sigemptyset(SigsetT*) : Int
  fun sigfillset(SigsetT*) : Int
  fun sigaddset(SigsetT*, Int) : Int
  fun sigdelset(SigsetT*, Int) : Int
  fun sigismember(SigsetT*, Int) : Int
end

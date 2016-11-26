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

  fun kill(pid : PidT, sig : Int) : Int
  fun signal(sig : Int, handler : Int -> Void) : Int -> Void
end

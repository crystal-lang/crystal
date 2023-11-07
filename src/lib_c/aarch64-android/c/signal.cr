require "./sys/types"
require "./time"

lib LibC
  SIGHUP    =  1
  SIGINT    =  2
  SIGQUIT   =  3
  SIGILL    =  4
  SIGTRAP   =  5
  SIGABRT   =  6
  SIGIOT    =  6
  SIGBUS    =  7
  SIGFPE    =  8
  SIGKILL   =  9
  SIGUSR1   = 10
  SIGSEGV   = 11
  SIGUSR2   = 12
  SIGPIPE   = 13
  SIGALRM   = 14
  SIGTERM   = 15
  SIGSTKFLT = 16
  SIGCHLD   = 17
  SIGCONT   = 18
  SIGSTOP   = 19
  SIGTSTP   = 20
  SIGTTIN   = 21
  SIGTTOU   = 22
  SIGURG    = 23
  SIGXCPU   = 24
  SIGXFSZ   = 25
  SIGVTALRM = 26
  SIGPROF   = 27
  SIGWINCH  = 28
  SIGIO     = 29
  SIGPOLL   = LibC::SIGIO
  SIGPWR    = 30
  SIGSYS    = 31
  SIGUNUSED = 31

  SIGSTKSZ = 16384

  SIG_SETMASK = 2

  alias SighandlerT = Int ->
  SIG_DFL = SighandlerT.new(Pointer(Void).new(0_u64), Pointer(Void).null)
  SIG_IGN = SighandlerT.new(Pointer(Void).new(1_u64), Pointer(Void).null)

  struct SigsetT
    val : ULong[1] # (_KERNEL__NSIG / _NSIG_BPW)
  end

  SA_ONSTACK = 0x08000000
  SA_SIGINFO = 0x00000004

  struct SiginfoT
    si_signo : Int
    si_errno : Int
    si_code : Int
    __pad0 : Int
    si_addr : Void*  # Assuming the sigfault form of siginfo_t
    __pad1 : Int[26] # SI_MAX_SIZE (128) / sizeof(int) - ...
  end

  alias SigactionHandlerT = (Int, SiginfoT*, Void*) ->

  struct Sigaction
    sa_flags : Int
    sa_sigaction : SigactionHandlerT
    sa_mask : SigsetT
    sa_restorer : ->
  end

  struct StackT
    ss_sp : Void*
    ss_flags : Int
    ss_size : ULong
  end

  fun kill(__pid : PidT, __signal : Int) : Int
  fun pthread_sigmask(__how : Int, __new_set : SigsetT*, __old_set : SigsetT*) : Int
  fun sigaction(__signal : Int, __new_action : Sigaction*, __old_action : Sigaction*) : Int
  fun sigaltstack(__new_signal_stack : StackT*, __old_signal_stack : StackT*) : Int
  {% if ANDROID_API >= 21 %}
    # TODO: defined inline for `ANDROID_API < 21`
    fun signal(__signal : Int, __handler : SighandlerT) : SighandlerT
    fun sigemptyset(__set : SigsetT*) : Int
    fun sigfillset(__set : SigsetT*) : Int
    fun sigaddset(__set : SigsetT*, __signal : Int) : Int
    fun sigdelset(__set : SigsetT*, __signal : Int) : Int
    fun sigismember(__set : SigsetT*, __signal : Int) : Int
  {% end %}
end

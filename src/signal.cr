require "c/signal"
require "c/stdio"
require "c/unistd"

{% if flag?(:linux) %}
  enum Signal
    HUP    = LibC::SIGHUP
    INT    = LibC::SIGINT
    QUIT   = LibC::SIGQUIT
    ILL    = LibC::SIGILL
    TRAP   = LibC::SIGTRAP
    IOT    = LibC::SIGIOT
    ABRT   = LibC::SIGABRT
    FPE    = LibC::SIGFPE
    KILL   = LibC::SIGKILL
    BUS    = LibC::SIGBUS
    SEGV   = LibC::SIGSEGV
    SYS    = LibC::SIGSYS
    PIPE   = LibC::SIGPIPE
    ALRM   = LibC::SIGALRM
    TERM   = LibC::SIGTERM
    URG    = LibC::SIGURG
    STOP   = LibC::SIGSTOP
    TSTP   = LibC::SIGTSTP
    CONT   = LibC::SIGCONT
    CHLD   = LibC::SIGCHLD
    TTIN   = LibC::SIGTTIN
    TTOU   = LibC::SIGTTOU
    IO     = LibC::SIGIO
    XCPU   = LibC::SIGXCPU
    XFSZ   = LibC::SIGXFSZ
    VTALRM = LibC::SIGVTALRM
    USR1   = LibC::SIGUSR1
    USR2   = LibC::SIGUSR2
    WINCH  = LibC::SIGWINCH

    PWR    = LibC::SIGPWR
    STKFLT = LibC::SIGSTKFLT
    UNUSED = LibC::SIGUNUSED
  end
{% else %}
  enum Signal
    HUP    = LibC::SIGHUP
    INT    = LibC::SIGINT
    QUIT   = LibC::SIGQUIT
    ILL    = LibC::SIGILL
    TRAP   = LibC::SIGTRAP
    IOT    = LibC::SIGIOT
    ABRT   = LibC::SIGABRT
    FPE    = LibC::SIGFPE
    KILL   = LibC::SIGKILL
    BUS    = LibC::SIGBUS
    SEGV   = LibC::SIGSEGV
    SYS    = LibC::SIGSYS
    PIPE   = LibC::SIGPIPE
    ALRM   = LibC::SIGALRM
    TERM   = LibC::SIGTERM
    URG    = LibC::SIGURG
    STOP   = LibC::SIGSTOP
    TSTP   = LibC::SIGTSTP
    CONT   = LibC::SIGCONT
    CHLD   = LibC::SIGCHLD
    TTIN   = LibC::SIGTTIN
    TTOU   = LibC::SIGTTOU
    IO     = LibC::SIGIO
    XCPU   = LibC::SIGXCPU
    XFSZ   = LibC::SIGXFSZ
    VTALRM = LibC::SIGVTALRM
    USR1   = LibC::SIGUSR1
    USR2   = LibC::SIGUSR2
    WINCH  = LibC::SIGWINCH
  end
{% end %}

# Signals are processed through the event loop and run in their own Fiber.
# Signals may be lost if the event loop doesn't run before exit.
# An uncaught exceptions in a signal handler is a fatal error.
enum Signal
  def trap(block : Signal ->)
    trap &block
  end

  def trap(&block : Signal ->)
    Event::SignalHandler.add_handler self, block
  end

  def reset
    case self
    when CHLD
      # don't ignore by default.  send events to a waitpid service
      trap do
        Event::SignalChildHandler.instance.trigger
        nil
      end
    else
      del_handler Proc(Int32, Void).new(Pointer(Void).new(0_u64), Pointer(Void).null)
    end
  end

  def ignore
    del_handler Proc(Int32, Void).new(Pointer(Void).new(1_u64), Pointer(Void).null)
  end

  private def del_handler(block)
    Event::SignalHandler.del_handler self
    LibC.signal value, block
  end

  @@default_handlers_setup = false

  # :nodoc:
  def self.setup_default_handlers
    return if @@default_handlers_setup
    @@default_handlers_setup = true

    Signal::PIPE.ignore
    Signal::CHLD.reset
  end
end

# :nodoc:
fun __crystal_sigfault_handler(sig : LibC::Int, addr : Void*)
  # Capture fault signals (SEGV, BUS) and finish the process printing a backtrace first
  LibC.printf "Invalid memory access (signal %d) at address 0x%lx\n", sig, addr
  CallStack.print_backtrace
  LibC._exit sig
end

LibExt.setup_sigfault_handler

require "crystal/system/signal"

# Safely handle inter-process signals on POSIX systems.
#
# Signals are dispatched to the event loop and later processed in a dedicated
# fiber. Some received signals may never be processed when the program
# terminates.
#
# ```
# puts "Ctrl+C still has the OS default action (stops the program)"
# sleep 3
#
# Signal::INT.trap do
#   puts "Gotcha!"
# end
# puts "Ctrl+C will be caught from now on"
# sleep 3
#
# Signal::INT.reset
# puts "Ctrl+C is back to the OS default action"
# sleep 3
# ```
#
# NOTE: `Process.on_interrupt` is preferred over `Signal::INT.trap`, as the
# former also works on Windows.
#
# WARNING: An uncaught exception in a signal handler is a fatal error.
enum Signal : Int32
  # Signals required by the ISO C standard. Since every supported platform must
  # bind against a C runtime, these constants must be defined at all times

  INT  = LibC::SIGINT
  ILL  = LibC::SIGILL
  FPE  = LibC::SIGFPE
  SEGV = LibC::SIGSEGV
  TERM = LibC::SIGTERM
  ABRT = LibC::SIGABRT

  {% if flag?(:win32) %}
    BREAK = LibC::SIGBREAK
  {% else %}
    HUP    = LibC::SIGHUP
    QUIT   = LibC::SIGQUIT
    TRAP   = LibC::SIGTRAP
    IOT    = LibC::SIGIOT
    KILL   = LibC::SIGKILL
    BUS    = LibC::SIGBUS
    SYS    = LibC::SIGSYS
    PIPE   = LibC::SIGPIPE
    ALRM   = LibC::SIGALRM
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

    {% if flag?(:linux) %}
      PWR    = LibC::SIGPWR
      STKFLT = LibC::SIGSTKFLT
      UNUSED = LibC::SIGUNUSED
    {% end %}
  {% end %}

  # Sets the handler for this signal to the passed function.
  #
  # After executing this, whenever the current process receives the
  # corresponding signal, the passed function will be called (instead of the OS
  # default). The handler will run in a signal-safe fiber thought the event
  # loop; there is no limit to what functions can be called, unlike raw signals
  # that run on the sigaltstack.
  #
  # Note that `CHLD` is always trapped and child processes will always be reaped
  # before the custom handler is called, hence a custom `CHLD` handler must
  # check child processes using `Process.exists?`. Trying to use waitpid with a
  # zero or negative value won't work.
  def trap(&handler : Signal ->) : Nil
    {% if @type.has_constant?("CHLD") %}
      if self == CHLD
        Crystal::System::Signal.child_handler = handler
        return
      end
    {% end %}
    Crystal::System::Signal.trap(self, handler)
  end

  # Resets the handler for this signal to the OS default.
  #
  # Note that trying to reset `CHLD` will actually set the default crystal
  # handler that monitors and reaps child processes. This prevents zombie
  # processes and is required by `Process#wait` for example.
  def reset : Nil
    Crystal::System::Signal.reset(self)
  end

  # Clears the handler for this signal and prevents the OS default action.
  #
  # Note that trying to ignore `CHLD` will actually set the default crystal
  # handler that monitors and reaps child processes. This prevents zombie
  # processes and is required by `Process#wait` for example.
  def ignore : Nil
    Crystal::System::Signal.ignore(self)
  end
end

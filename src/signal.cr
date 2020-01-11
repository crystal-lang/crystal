require "c/signal"
require "c/stdio"
require "c/sys/wait"
require "c/unistd"

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
# Note:
# - An uncaught exception in a signal handler is a fatal error.
enum Signal : Int32
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

  {% if flag?(:linux) %}
    PWR    = LibC::SIGPWR
    STKFLT = LibC::SIGSTKFLT
    UNUSED = LibC::SIGUNUSED
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
    if self == CHLD
      Crystal::Signal.child_handler = handler
    else
      Crystal::Signal.trap(self, handler)
    end
  end

  # Resets the handler for this signal to the OS default.
  #
  # Note that trying to reset `CHLD` will actually set the default crystal
  # handler that monitors and reaps child processes. This prevents zombie
  # processes and is required by `Process#wait` for example.
  def reset : Nil
    Crystal::Signal.reset(self)
  end

  # Clears the handler for this signal and prevents the OS default action.
  #
  # Note that trying to ignore `CHLD` will actually set the default crystal
  # handler that monitors and reaps child processes. This prevents zombie
  # processes and is required by `Process#wait` for example.
  def ignore : Nil
    Crystal::Signal.ignore(self)
  end

  {% if flag?(:darwin) || flag?(:openbsd) %}
    @@sigset = LibC::SigsetT.new(0)
  {% else %}
    @@sigset = LibC::SigsetT.new
  {% end %}

  # :nodoc:
  def set_add : Nil
    LibC.sigaddset(pointerof(@@sigset), self)
  end

  # :nodoc:
  def set_del : Nil
    LibC.sigdelset(pointerof(@@sigset), self)
  end

  # :nodoc:
  def set? : Bool
    LibC.sigismember(pointerof(@@sigset), self) == 1
  end

  @@setup_default_handlers = Atomic::Flag.new

  # :nodoc:
  def self.setup_default_handlers
    return unless @@setup_default_handlers.test_and_set
    LibC.sigemptyset(pointerof(@@sigset))
    Crystal::Signal.start_loop
    Signal::PIPE.ignore
    Signal::CHLD.reset
  end
end

# :nodoc:
module Crystal::Signal
  # The number of libc functions that can be called safely from a signal(2)
  # handler is very limited. An usual safe solution is to use a pipe(2) and
  # just write the signal to the file descriptor and nothing more. A loop in
  # the main program is responsible for reading the signals back from the
  # pipe(2) and handle the signal there.

  alias Handler = ::Signal ->

  @@pipe = IO.pipe(read_blocking: false, write_blocking: true)
  @@handlers = {} of ::Signal => Handler
  @@child_handler : Handler?
  @@mutex = Mutex.new(:unchecked)

  def self.trap(signal, handler) : Nil
    @@mutex.synchronize do
      unless @@handlers[signal]?
        signal.set_add
        LibC.signal(signal.value, ->(value : Int32) {
          writer.write_bytes(value) unless writer.closed?
        })
      end
      @@handlers[signal] = handler
    end
  end

  def self.child_handler=(handler : Handler) : Nil
    @@child_handler = handler
  end

  def self.reset(signal) : Nil
    set(signal, LibC::SIG_DFL)
  end

  def self.ignore(signal) : Nil
    set(signal, LibC::SIG_IGN)
  end

  private def self.set(signal, handler)
    if signal == ::Signal::CHLD
      # Clear any existing signal child handler
      @@child_handler = nil
      # But keep a default SIGCHLD, Process#wait requires it
      trap(signal, ->(signal : ::Signal) {
        Crystal::SignalChildHandler.call
        @@child_handler.try(&.call(signal))
      })
    else
      @@mutex.synchronize do
        @@handlers.delete(signal)
        LibC.signal(signal, handler)
        signal.set_del
      end
    end
  end

  def self.start_loop
    spawn(name: "Signal Loop") do
      loop do
        value = reader.read_bytes(Int32)
      rescue Errno
        next
      else
        process(::Signal.new(value))
      end
    end
  end

  private def self.process(signal) : Nil
    if handler = @@handlers[signal]?
      non_nil_handler = handler # if handler is closured it will also have the Nil type
      spawn do
        non_nil_handler.call(signal)
      rescue ex
        ex.inspect_with_backtrace(STDERR)
        fatal("uncaught exception while processing handler for #{signal}")
      end
    else
      fatal("missing handler for #{signal}")
    end
  end

  # Replaces the signal pipe so the child process won't share the file
  # descriptors of the parent process and send it received signals.
  def self.after_fork
    @@pipe.each(&.close)
  ensure
    @@pipe = IO.pipe(read_blocking: false, write_blocking: true)
  end

  # Resets signal handlers to `SIG_DFL`. This avoids the child to receive
  # signals that would be sent to the parent process through the signal
  # pipe.
  #
  # We keep a signal set to because accessing @@handlers ins't thread safe —a
  # thread could be mutating the hash while another one forked. This allows to
  # only reset a few signals (fast) rather than all (very slow).
  #
  # We eventually close the pipe anyway to avoid a potential race where a sigset
  # wouldn't exactly reflect actual signal state. This avoids sending a children
  # signal to the parent. Exec will reset the signals properly for the
  # sub-process.
  def self.after_fork_before_exec
    ::Signal.each do |signal|
      LibC.signal(signal, LibC::SIG_DFL) if signal.set?
    end
  ensure
    {% unless flag?(:preview_mt) %}
      @@pipe.each(&.close)
    {% end %}
  end

  private def self.reader
    @@pipe[0]
  end

  private def self.writer
    @@pipe[1]
  end

  private def self.fatal(message : String)
    STDERR.puts("FATAL: #{message}, exiting")
    STDERR.flush
    LibC._exit(1)
  end
end

# :nodoc:
module Crystal::SignalChildHandler
  # Process#wait will block until the sub-process has terminated. On POSIX
  # systems, the SIGCHLD signal is triggered. We thus always trap SIGCHLD then
  # reap/memorize terminated child processes and eventually notify
  # Process#wait through a channel, that may be created before or after the
  # child process exited.

  @@pending = {} of LibC::PidT => Int32
  @@waiting = {} of LibC::PidT => Channel(Int32)
  @@mutex = Mutex.new(:unchecked)

  def self.wait(pid : LibC::PidT) : Channel(Int32)
    channel = Channel(Int32).new(1)

    @@mutex.lock
    if exit_code = @@pending.delete(pid)
      @@mutex.unlock
      channel.send(exit_code)
      channel.close
    else
      @@waiting[pid] = channel
      @@mutex.unlock
    end

    channel
  end

  def self.call : Nil
    loop do
      pid = LibC.waitpid(-1, out exit_code, LibC::WNOHANG)

      case pid
      when 0
        return
      when -1
        return if Errno.value == Errno::ECHILD
        raise Errno.new("waitpid")
      end

      @@mutex.lock
      if channel = @@waiting.delete(pid)
        @@mutex.unlock
        channel.send(exit_code)
        channel.close
      else
        @@pending[pid] = exit_code
        @@mutex.unlock
      end
    end
  end

  def self.after_fork
    @@pending.clear
    @@waiting.each_value(&.close)
    @@waiting.clear
  end
end

# :nodoc:
fun __crystal_sigfault_handler(sig : LibC::Int, addr : Void*)
  # Capture fault signals (SEGV, BUS) and finish the process printing a backtrace first

  # Determine if the SEGV was inside or 'near' the top of the stack
  # to check for potential stack overflow. 'Near' is a small
  # amount larger than a typical stack frame, 4096 bytes here.
  stack_top = Pointer(Void).new(Fiber.current.@stack.address - 4096)

  if stack_top <= addr < Fiber.current.@stack_bottom
    LibC.dprintf 2, "Stack overflow (e.g., infinite or very deep recursion)\n"
  else
    LibC.dprintf 2, "Invalid memory access (signal %d) at address 0x%lx\n", sig, addr
  end

  CallStack.print_backtrace
  LibC._exit(sig)
end

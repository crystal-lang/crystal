require "c/signal"
require "c/stdlib"
require "c/sys/times"
require "c/sys/wait"
require "c/unistd"

class Process
  # Terminate the current process immediately. All open files, pipes and sockets
  # are flushed and closed, all child processes are inherited by PID 1. This does
  # not run any handlers registered with `at_exit`, use `::exit` for that.
  #
  # *status* is the exit status of the current process.
  def self.exit(status = 0)
    LibC.exit(status)
  end

  # Returns the process identifier of the current process.
  def self.pid : LibC::PidT
    LibC.getpid
  end

  # Returns the process group identifier of the current process.
  def self.pgid : LibC::PidT
    pgid(0)
  end

  # Returns the process group identifier of the process identified by *pid*.
  def self.pgid(pid : Int32) : LibC::PidT
    ret = LibC.getpgid(pid)
    raise Errno.new("getpgid") if ret < 0
    ret
  end

  # Returns the process identifier of the parent process of the current process.
  def self.ppid : LibC::PidT
    LibC.getppid
  end

  # Sends a signal to the processes identified by the given *pids*.
  def self.kill(signal : Signal, *pids : Int)
    pids.each do |pid|
      ret = LibC.kill(pid, signal.value)
      raise Errno.new("kill") if ret < 0
    end
    nil
  end

  # A struct representing the CPU current times of the process, in fractions of seconds.
  #
  # * *utime* CPU time a process spent in userland.
  # * *stime* CPU time a process spent in the kernel.
  # * *cutime* CPU time a processes terminated children (and their terminated children) spent in the userland.
  # * *cstime* CPU time a processes terminated children (and their terminated children) spent in the kernel.
  record Tms, utime : Float64, stime : Float64, cutime : Float64, cstime : Float64

  # Returns a `Tms` for the current process. For the children times, only those
  # of terminated children are returned.
  def self.times : Tms
    hertz = LibC.sysconf(LibC::SC_CLK_TCK).to_f
    LibC.times(out tms)
    Tms.new(tms.tms_utime / hertz, tms.tms_stime / hertz, tms.tms_cutime / hertz, tms.tms_cstime / hertz)
  end

  # Runs the given block inside a new process and
  # returns a `Process` representing the new child process.
  def self.fork
    pid = fork_internal do
      with self yield self
    end
    Process.new pid
  end

  # Duplicates the current process.
  # Returns a `Process` representing the new child process in the current process
  # and nil inside the new child process.
  def self.fork : self?
    if pid = fork_internal
      Process.new pid
    else
      nil
    end
  end

  # :nodoc:
  protected def self.fork_internal(run_hooks : Bool = true, &block)
    pid = self.fork_internal(run_hooks)

    unless pid
      begin
        yield
        LibC._exit 0
      rescue ex
        ex.inspect STDERR
        STDERR.flush
        LibC._exit 1
      ensure
        LibC._exit 254 # not reached
      end
    end

    pid
  end

  # run_hooks should ALWAYS be true unless exec* is used immediately after fork.
  # Channels, IO and other will not work reliably if run_hooks is false.
  protected def self.fork_internal(run_hooks : Bool = true)
    pid = LibC.fork
    case pid
    when 0
      pid = nil
      Process.after_fork_child_callbacks.each(&.call) if run_hooks
    when -1
      raise Errno.new("fork")
    end
    pid
  end
end

# See `Process.fork`
def fork
  Process.fork { yield }
end

# See `Process.fork`
def fork
  Process.fork
end

require "./process/*"

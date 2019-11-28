require "c/signal"
require "c/stdlib"
require "c/sys/resource"
require "c/unistd"

class Process
  private def initialize(@pid)
    @waitpid = Process.wait_system(pid)
    @wait_count = 0
  end

  protected def self.wait_system(pid : Int64) : Channel(Int32)
    Crystal::SignalChildHandler.wait(pid)
  end

  protected def self.exit_system(status = 0) : NoReturn
    LibC.exit(status)
  end

  protected def self.pid_system : Int64
    LibC.getpid.to_i64
  end

  # Returns the process group identifier of the current process.
  def self.pgid : Int64
    self.pgid_system
  end

  protected def self.exists_system(pid : Int64)
    ret = LibC.kill(pid.to_i32, 0)
    return true if ret == 0
    return false if Errno.value == Errno::ESRCH
    raise Errno.new("kill")
  end

  # Returns the process group identifier of the current process.
  protected def self.pgid_system : Int64
    pgid(0)
  end

  # Returns the process group identifier of the process identified by *pid*.
  def self.pgid(pid : Int64) : Int64
    ret = LibC.getpgid(pid)
    raise Errno.new("getpgid") if ret < 0
    ret.to_i64
  end

  protected def self.ppid_system : Int64
    LibC.getppid.to_i64
  end

  protected def terminate_system
    signal Signal::TERM
  end

  protected def kill_system
    signal Signal::KILL
  end

  # See also: `Process.signal`
  def signal(sig = Signal::TERM)
    Process.signal sig, @pid
  end

  # Sends a *signal* to the processes identified by the given *pids*.
  def self.signal(signal : Signal, *pids : Int)
    pids.each do |pid|
      ret = LibC.kill(pid, signal.value)
      raise Errno.new("kill") if ret < 0
    end
  end

  # Creates a process, executes it
  protected def create_and_exec(command : String, args : (Array | Tuple)?, env : Env?, clear_env : Bool, fork_input : IO::FileDescriptor, fork_output : IO::FileDescriptor, fork_error : IO::FileDescriptor, chdir : String?, reader_pipe, writer_pipe)
    if pid = Process.fork_internal(will_exec: true)
      pid
    else
      begin
        reader_pipe.close
        writer_pipe.close_on_exec = true
        Process.exec_internal(command, args, env, clear_env, fork_input, fork_output, fork_error, chdir)
      rescue ex : Errno
        writer_pipe.write_bytes(ex.errno)
        writer_pipe.write_bytes(ex.message.try(&.bytesize) || 0)
        writer_pipe << ex.message
        writer_pipe.close
      rescue ex
        ex.inspect_with_backtrace STDERR
        STDERR.flush
      ensure
        LibC._exit 127
      end
    end
  end

  # Runs the given block inside a new process and
  # returns a `Process` representing the new child process.
  def self.fork : Process
    {% raise("Process fork is unsupported with multithread mode") if flag?(:preview_mt) %}
    if pid = fork_internal(will_exec: false)
      new pid
    else
      begin
        yield
        LibC._exit 0
      rescue ex
        ex.inspect_with_backtrace STDERR
        STDERR.flush
        LibC._exit 1
      ensure
        LibC._exit 254 # not reached
      end
    end
  end

  # Duplicates the current process.
  # Returns a `Process` representing the new child process in the current process
  # and `nil` inside the new child process.
  def self.fork : Process?
    {% raise("Process fork is unsupported with multithread mode") if flag?(:preview_mt) %}

    if pid = fork_internal(will_exec: false)
      new pid
    else
      nil
    end
  end

  ORIGINAL_STDIN  = IO::FileDescriptor.new(0, blocking: true)
  ORIGINAL_STDOUT = IO::FileDescriptor.new(1, blocking: true)
  ORIGINAL_STDERR = IO::FileDescriptor.new(2, blocking: true)

  protected def self.reopen_io(src_io : IO::FileDescriptor, dst_io : IO::FileDescriptor)
    src_io = to_real_fd(src_io)
    dst_io.reopen(src_io)
    dst_io.blocking = true
    dst_io.close_on_exec = false
  end

  protected def self.to_real_fd(fd : IO::FileDescriptor)
    case fd
    when STDIN  then ORIGINAL_STDIN
    when STDOUT then ORIGINAL_STDOUT
    when STDERR then ORIGINAL_STDERR
    else             fd
    end
  end

  # :nodoc:
  protected def self.exec_internal(command, args : (Array | Tuple)?, env, clear_env, input, output, error, chdir) : NoReturn
    reopen_io(input, ORIGINAL_STDIN)
    reopen_io(output, ORIGINAL_STDOUT)
    reopen_io(error, ORIGINAL_STDERR)

    ENV.clear if clear_env
    env.try &.each do |key, val|
      if val
        ENV[key] = val
      else
        ENV.delete key
      end
    end

    Dir.cd(chdir) if chdir

    argv = [command.check_no_null_byte.to_unsafe]
    args.try &.each do |arg|
      argv << arg.check_no_null_byte.to_unsafe
    end
    argv << Pointer(UInt8).null

    LibC.execvp(command, argv)

    error_message = String.build do |io|
      io << "execvp ("
      command.inspect_unquoted(io)
      args.try &.each do |arg|
        io << ' '
        arg.inspect(io)
      end
      io << ")"
    end
    raise Errno.new(error_message)
  end

  protected def self.system_prepare_shell(command, args)
    command = %(#{command} "${@}") unless command.includes?(' ')
    shell_args = ["-c", command, "--"]

    if args
      unless command.includes?(%("${@}"))
        raise ArgumentError.new(%(can't specify arguments in both, command and args without including "${@}" into your command))
      end

      {% if flag?(:freebsd) %}
        shell_args << ""
      {% end %}

      shell_args.concat(args)
    end

    command = "/bin/sh"
    args = shell_args
    {command, args}
  end

  # :nodoc:
  protected def self.fork_internal(*, will_exec : Bool) : Int64?
    newmask = uninitialized LibC::SigsetT
    oldmask = uninitialized LibC::SigsetT

    LibC.sigfillset(pointerof(newmask))
    ret = LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(newmask), pointerof(oldmask))
    raise Errno.new("Failed to disable signals") unless ret == 0

    case pid = LibC.fork
    when 0
      # child:
      pid = nil
      if will_exec
        # reset signal handlers, then sigmask (inherited on exec):
        Crystal::Signal.after_fork_before_exec
        LibC.sigemptyset(pointerof(newmask))
        LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(newmask), nil)
      else
        {% unless flag?(:preview_mt) %}
          ::Process.after_fork_child_callbacks.each(&.call)
        {% end %}
        LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
      end
    when -1
      # error:
      errno = Errno.value
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
      raise Errno.new("fork", errno)
    else
      # parent:
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
    end

    pid.try &.to_i64
  end

  protected def close_system
  end

  # Changes the root directory and the current working directory for the current
  # process.
  #
  # Security: `chroot` on its own is not an effective means of mitigation. At minimum
  # the process needs to also drop privileges as soon as feasible after the `chroot`.
  # Changes to the directory hierarchy or file descriptors passed via `recvmsg(2)` from
  # outside the `chroot` jail may allow a restricted process to escape, even if it is
  # unprivileged.
  #
  # ```
  # Process.chroot("/var/empty")
  # ```
  def self.chroot(path : String) : Nil
    path.check_no_null_byte
    if LibC.chroot(path) != 0
      raise Errno.new("Failed to chroot")
    end

    if LibC.chdir("/") != 0
      errno = Errno.new("chdir after chroot failed")
      errno.callstack = CallStack.new
      errno.inspect_with_backtrace(STDERR)
      abort("Unresolvable state, exiting...")
    end
  end
end

# See also: `Process.fork`
def fork
  ::Process.fork { yield }
end

# See also: `Process.fork`
def fork
  ::Process.fork
end

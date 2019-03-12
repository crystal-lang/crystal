require "c/signal"
require "c/stdlib"
require "c/sys/times"
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

  # Sends a *signal* to the processes identified by the given *pids*.
  def self.kill(signal : Signal, *pids : Int)
    pids.each do |pid|
      ret = LibC.kill(pid, signal.value)
      raise Errno.new("kill") if ret < 0
    end
    nil
  end

  # Returns `true` if the process identified by *pid* is valid for
  # a currently registered process, `false` otherwise. Note that this
  # returns `true` for a process in the zombie or similar state.
  def self.exists?(pid : Int)
    ret = LibC.kill(pid, 0)
    if ret == 0
      true
    else
      return false if Errno.value == Errno::ESRCH
      raise Errno.new("kill")
    end
  end

  # A struct representing the CPU current times of the process,
  # in fractions of seconds.
  #
  # * *utime*: CPU time a process spent in userland.
  # * *stime*: CPU time a process spent in the kernel.
  # * *cutime*: CPU time a processes terminated children (and their terminated children) spent in the userland.
  # * *cstime*: CPU time a processes terminated children (and their terminated children) spent in the kernel.
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
  def self.fork : Process
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
    if pid = fork_internal(will_exec: false)
      new pid
    else
      nil
    end
  end

  # :nodoc:
  protected def self.fork_internal(*, will_exec : Bool)
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
        Process.after_fork_child_callbacks.each(&.call)
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

    pid
  end

  # How to redirect the standard input, output and error IO of a process.
  enum Redirect
    # Pipe the IO so the parent process can read (or write) to the process IO
    # through `#input`, `#output` or `#error`.
    Pipe

    # Discards the IO.
    Close

    # Use the IO of the parent process.
    Inherit
  end

  # The standard `IO` configuration of a process.
  alias Stdio = Redirect | IO
  alias ExecStdio = Redirect | IO::FileDescriptor
  alias Env = Nil | Hash(String, Nil) | Hash(String, String?) | Hash(String, String)

  # Executes a process and waits for it to complete.
  #
  # By default the process is configured without input, output or error.
  def self.run(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
               input : Stdio = Redirect::Close, output : Stdio = Redirect::Close, error : Stdio = Redirect::Close, chdir : String? = nil) : Process::Status
    status = new(command, args, env, clear_env, shell, input, output, error, chdir).wait
    $? = status
    status
  end

  # Executes a process, yields the block, and then waits for it to finish.
  #
  # By default the process is configured to use pipes for input, output and error. These
  # will be closed automatically at the end of the block.
  #
  # Returns the block's value.
  def self.run(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
               input : Stdio = Redirect::Pipe, output : Stdio = Redirect::Pipe, error : Stdio = Redirect::Pipe, chdir : String? = nil)
    process = new(command, args, env, clear_env, shell, input, output, error, chdir)
    begin
      value = yield process
      $? = process.wait
      value
    rescue ex
      process.kill
      raise ex
    end
  end

  # Replaces the current process with a new one. This function never returns.
  def self.exec(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
                input : ExecStdio = Redirect::Inherit, output : ExecStdio = Redirect::Inherit, error : ExecStdio = Redirect::Inherit, chdir : String? = nil)
    command, args = prepare_args(command, args, shell)

    input = exec_stdio_to_fd(input, for: STDIN)
    output = exec_stdio_to_fd(output, for: STDOUT)
    error = exec_stdio_to_fd(error, for: STDERR)

    exec_internal(command, args, env, clear_env, input, output, error, chdir)
  end

  private def self.exec_stdio_to_fd(stdio : ExecStdio, for dst_io : IO::FileDescriptor) : IO::FileDescriptor
    case stdio
    when IO::FileDescriptor
      stdio
    when Redirect::Pipe
      raise "Cannot use Process::Redirect::Pipe for Process.exec"
    when Redirect::Inherit
      dst_io
    when Redirect::Close
      if dst_io == STDIN
        File.open(File::DEVNULL, "r")
      else
        File.open(File::DEVNULL, "w")
      end
    else
      raise "BUG: impossible type in ExecStdio #{stdio.class}"
    end
  end

  getter pid : Int32

  # A pipe to this process's input. Raises if a pipe wasn't asked when creating the process.
  getter! input : IO::FileDescriptor

  # A pipe to this process's output. Raises if a pipe wasn't asked when creating the process.
  getter! output : IO::FileDescriptor

  # A pipe to this process's error. Raises if a pipe wasn't asked when creating the process.
  getter! error : IO::FileDescriptor

  @waitpid : Channel::Buffered(Int32)
  @wait_count = 0

  # Creates a process, executes it, but doesn't wait for it to complete.
  #
  # To wait for it to finish, invoke `wait`.
  #
  # By default the process is configured without input, output or error.
  def initialize(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
                 input : Stdio = Redirect::Close, output : Stdio = Redirect::Close, error : Stdio = Redirect::Close, chdir : String? = nil)
    command, args = Process.prepare_args(command, args, shell)

    fork_input = stdio_to_fd(input, for: STDIN)
    fork_output = stdio_to_fd(output, for: STDOUT)
    fork_error = stdio_to_fd(error, for: STDERR)

    reader_pipe, writer_pipe = IO.pipe

    if pid = Process.fork_internal(will_exec: true)
      @pid = pid
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

    writer_pipe.close
    bytes = uninitialized UInt8[4]
    if reader_pipe.read(bytes.to_slice) == 4
      errno = IO::ByteFormat::SystemEndian.decode(Int32, bytes.to_slice)
      message_size = reader_pipe.read_bytes(Int32)
      if message_size > 0
        message = String.build(message_size) { |io| IO.copy(reader_pipe, io, message_size) }
      end
      reader_pipe.close
      raise Errno.new(message, errno)
    end
    reader_pipe.close

    @waitpid = Crystal::SignalChildHandler.wait(pid)

    fork_input.close unless fork_input == input || fork_input == STDIN
    fork_output.close unless fork_output == output || fork_output == STDOUT
    fork_error.close unless fork_error == error || fork_error == STDERR
  end

  private def stdio_to_fd(stdio : Stdio, for dst_io : IO::FileDescriptor) : IO::FileDescriptor
    case stdio
    when IO::FileDescriptor
      stdio
    when IO
      if dst_io == STDIN
        fork_io, process_io = IO.pipe(read_blocking: true)

        @wait_count += 1
        spawn { copy_io(stdio, process_io, channel, close_dst: true) }
      else
        process_io, fork_io = IO.pipe(write_blocking: true)

        @wait_count += 1
        spawn { copy_io(process_io, stdio, channel, close_src: true) }
      end

      fork_io
    when Redirect::Pipe
      case dst_io
      when STDIN
        fork_io, @input = IO.pipe(read_blocking: true)
      when STDOUT
        @output, fork_io = IO.pipe(write_blocking: true)
      when STDERR
        @error, fork_io = IO.pipe(write_blocking: true)
      else
        raise "BUG: unknown destination io #{dst_io}"
      end

      fork_io
    when Redirect::Inherit
      dst_io
    when Redirect::Close
      if dst_io == STDIN
        File.open(File::DEVNULL, "r")
      else
        File.open(File::DEVNULL, "w")
      end
    else
      raise "BUG: impossible type in stdio #{stdio.class}"
    end
  end

  private def initialize(@pid)
    @waitpid = Crystal::SignalChildHandler.wait(pid)
    @wait_count = 0
  end

  # See also: `Process.kill`
  def kill(sig = Signal::TERM)
    Process.kill sig, @pid
  end

  # Waits for this process to complete and closes any pipes.
  def wait : Process::Status
    close_io @input # only closed when a pipe was created but not managed by copy_io

    @wait_count.times do
      ex = channel.receive
      raise ex if ex
    end
    @wait_count = 0

    Process::Status.new(@waitpid.receive)
  ensure
    close
  end

  # Whether the process is still registered in the system.
  # Note that this returns `true` for processes in the zombie or similar state.
  def exists?
    !terminated?
  end

  # Whether this process is already terminated.
  def terminated?
    @waitpid.closed? || !Process.exists?(@pid)
  end

  # Closes any pipes to the child process.
  def close
    close_io @input
    close_io @output
    close_io @error
  end

  # :nodoc:
  protected def self.prepare_args(command, args, shell)
    if shell
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
    end

    {command, args}
  end

  private def channel
    @channel ||= Channel(Exception?).new
  end

  private def needs_pipe?(io)
    (io == Redirect::Pipe) || (io.is_a?(IO) && !io.is_a?(IO::FileDescriptor))
  end

  private def copy_io(src, dst, channel, close_src = false, close_dst = false)
    return unless src.is_a?(IO) && dst.is_a?(IO)

    begin
      IO.copy(src, dst)

      # close is called here to trigger exceptions
      # close must be called before channel.send or the process may deadlock
      src.close if close_src
      close_src = false
      dst.close if close_dst
      close_dst = false

      channel.send nil
    rescue ex
      channel.send ex
    ensure
      # any exceptions are silently ignored because of spawn
      src.close if close_src
      dst.close if close_dst
    end
  end

  ORIGINAL_STDIN  = IO::FileDescriptor.new(0, blocking: true)
  ORIGINAL_STDOUT = IO::FileDescriptor.new(1, blocking: true).tap { |f| f.flush_on_newline = true }
  ORIGINAL_STDERR = IO::FileDescriptor.new(2, blocking: true).tap { |f| f.flush_on_newline = true }

  # :nodoc:
  protected def self.exec_internal(command, args, env, clear_env, input, output, error, chdir) : NoReturn
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

  private def self.reopen_io(src_io : IO::FileDescriptor, dst_io : IO::FileDescriptor)
    src_io = to_real_fd(src_io)

    dst_io.reopen(src_io)
    dst_io.blocking = true
    dst_io.close_on_exec = false
  end

  private def self.to_real_fd(fd : IO::FileDescriptor)
    case fd
    when STDIN  then ORIGINAL_STDIN
    when STDOUT then ORIGINAL_STDOUT
    when STDERR then ORIGINAL_STDERR
    else             fd
    end
  end

  private def close_io(io)
    io.close if io
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

# Executes the given command in a subshell.
# Standard input, output and error are inherited.
# Returns `true` if the command gives zero exit code, `false` otherwise.
# The special `$?` variable is set to a `Process::Status` associated with this execution.
#
# If *command* contains no spaces and *args* is given, it will become
# its argument list.
#
# If *command* contains spaces and *args* is given, *command* must include
# `"${@}"` (including the quotes) to receive the argument list.
#
# No shell interpretation is done in *args*.
#
# Example:
#
# ```
# system("echo *")
# ```
#
# Produces:
#
# ```text
# LICENSE shard.yml Readme.md spec src
# ```
def system(command : String, args = nil) : Bool
  status = Process.run(command, args, shell: true, input: Process::Redirect::Inherit, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
  $? = status
  status.success?
end

# Returns the standard output of executing *command* in a subshell.
# Standard input, and error are inherited.
# The special `$?` variable is set to a `Process::Status` associated with this execution.
#
# Example:
#
# ```
# `echo hi` # => "hi\n"
# ```
def `(command) : String
  process = Process.new(command, shell: true, input: Process::Redirect::Inherit, output: Process::Redirect::Pipe, error: Process::Redirect::Inherit)
  output = process.output.gets_to_end
  status = process.wait
  $? = status
  output
end

# See also: `Process.fork`
def fork
  Process.fork { yield }
end

# See also: `Process.fork`
def fork
  Process.fork
end

require "./process/*"

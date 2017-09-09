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
  def self.fork
    pid = fork_internal do
      with self yield self
    end
    new pid
  end

  # Duplicates the current process.
  # Returns a `Process` representing the new child process in the current process
  # and `nil` inside the new child process.
  def self.fork : self?
    if pid = fork_internal
      new pid
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

  # *run_hooks* should ALWAYS be `true` unless `exec` is used immediately after fork.
  # Channels, `IO` and other will not work reliably if *run_hooks* is `false`.
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

  # How to redirect the standard input, output and error IO of a process.
  enum Redirect
    # Pipe the IO so the parent process can read (or write) to the process IO
    # throught `#input`, `#output` or `#error`.
    Pipe

    # Discards the IO.
    Close

    # Use the IO of the parent process.
    Inherit
  end

  # The standard `IO` configuration of a process.
  alias Stdio = Redirect | IO
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

  # Replaces the current process with a new one.
  #
  # The possible values for *input*, *output* and *error* are:
  # * `false`: no `IO` (`/dev/null`)
  # * `true`: inherit from parent
  # * `IO`: use the given `IO`
  def self.exec(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
                input : Stdio = Redirect::Inherit, output : Stdio = Redirect::Inherit, error : Stdio = Redirect::Inherit, chdir : String? = nil)
    command, argv = prepare_argv(command, args, shell)
    exec_internal(command, argv, env, clear_env, input, output, error, chdir)
  end

  getter pid : Int32

  # A pipe to this process's input. Raises if a pipe wasn't asked when creating the process.
  getter! input : IO::FileDescriptor

  # A pipe to this process's output. Raises if a pipe wasn't asked when creating the process.
  getter! output : IO::FileDescriptor

  # A pipe to this process's error. Raises if a pipe wasn't asked when creating the process.
  getter! error : IO::FileDescriptor

  @waitpid_future : Concurrent::Future(Process::Status)

  # Creates a process, executes it, but doesn't wait for it to complete.
  #
  # To wait for it to finish, invoke `wait`.
  #
  # By default the process is configured without input, output or error.
  def initialize(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
                 input : Stdio = Redirect::Close, output : Stdio = Redirect::Close, error : Stdio = Redirect::Close, chdir : String? = nil)
    command, argv = Process.prepare_argv(command, args, shell)

    @wait_count = 0

    if needs_pipe?(input)
      fork_input, process_input = IO.pipe(read_blocking: true)
      if input.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(input, process_input, channel, close_dst: true) }
      else
        @input = process_input
      end
    end

    if needs_pipe?(output)
      process_output, fork_output = IO.pipe(write_blocking: true)
      if output.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(process_output, output, channel, close_src: true) }
      else
        @output = process_output
      end
    end

    if needs_pipe?(error)
      process_error, fork_error = IO.pipe(write_blocking: true)
      if error.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(process_error, error, channel, close_src: true) }
      else
        @error = process_error
      end
    end

    @pid = Process.fork_internal(run_hooks: false) do
      begin
        Process.exec_internal(
          command,
          argv,
          env,
          clear_env,
          fork_input || input,
          fork_output || output,
          fork_error || error,
          chdir
        )
      rescue ex
        ex.inspect_with_backtrace STDERR
      ensure
        LibC._exit 127
      end
    end

    @waitpid_future = Event::SignalChildHandler.instance.waitpid(pid)

    fork_input.try &.close
    fork_output.try &.close
    fork_error.try &.close
  end

  private def initialize(@pid)
    @waitpid_future = Event::SignalChildHandler.instance.waitpid(pid)
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

    @waitpid_future.get
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
    @waitpid_future.completed? || !Process.exists?(@pid)
  end

  # Closes any pipes to the child process.
  def close
    close_io @input
    close_io @output
    close_io @error
  end

  # :nodoc:
  protected def self.prepare_argv(command, args, shell)
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

    argv = [command.to_unsafe]
    args.try &.each do |arg|
      argv << arg.to_unsafe
    end
    argv << Pointer(UInt8).null

    {command, argv}
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

  # :nodoc:
  protected def self.exec_internal(command : String, argv, env, clear_env, input, output, error, chdir)
    reopen_io(input, STDIN, "r")
    reopen_io(output, STDOUT, "w")
    reopen_io(error, STDERR, "w")

    ENV.clear if clear_env
    env.try &.each do |key, val|
      if val
        ENV[key] = val
      else
        ENV.delete key
      end
    end

    Dir.cd(chdir) if chdir

    if LibC.execvp(command, argv) == -1
      raise Errno.new("execvp")
    end
  end

  private def self.reopen_io(src_io, dst_io, mode)
    case src_io
    when IO::FileDescriptor
      src_io.blocking = true
      dst_io.reopen(src_io)
    when Redirect::Inherit
      dst_io.blocking = true
    when Redirect::Close
      File.open("/dev/null", mode) do |file|
        dst_io.reopen(file)
      end
    else
      raise "BUG: unknown object type #{src_io}"
    end

    dst_io.close_on_exec = false
  end

  private def close_io(io)
    io.close if io
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

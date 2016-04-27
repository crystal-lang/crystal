require "c/unistd"

class Process
  # The standard io configuration of a process:
  #
  # * `nil`: use a pipe
  # * `false`: no IO (`/dev/null`)
  # * `true`: inherit from parent
  # * `IO`: use the given IO
  alias Stdio = Nil | Bool | IO
  alias Env = Nil | Hash(String, Nil) | Hash(String, String?) | Hash(String, String)

  # Executes a process and waits for it to complete.
  #
  # By default the process is configured without input, output or error.
  def self.run(cmd : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false, input : Stdio = false, output : Stdio = false, error : Stdio = false, chdir : String? = nil) : Process::Status
    status = new(cmd, args, env, clear_env, shell, input, output, error, chdir).wait
    $? = status
    status
  end

  # Executes a process, yields the block, and then waits for it to finish.
  #
  # By default the process is configured to use pipes for input, output and error. These
  # will be closed automatically at the end of the block.
  #
  # Returns the block's value.
  def self.run(cmd : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false, input : Stdio = nil, output : Stdio = nil, error : Stdio = nil, chdir : String? = nil)
    process = new(cmd, args, env, clear_env, shell, input, output, error, chdir)
    begin
      value = yield process
      $? = process.wait
      value
    rescue ex
      process.kill
      raise ex
    end
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
  def initialize(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false, input : Stdio = false, output : Stdio = false, error : Stdio = false, chdir : String? = nil)
    if shell
      command = %(#{command} "${@}") unless command.includes?(' ')
      shell_args = ["-c", command, "--"]

      if args
        unless command.includes?(%("${@}"))
          raise ArgumentError.new(%(can't specify arguments in both, command and args without including "${@}" into your command))
        end

        ifdef freebsd
          shell_args << ""
        end

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

    @wait_count = 0

    if needs_pipe?(input)
      fork_input, process_input = IO.pipe(read_blocking: true)
      if input
        @wait_count += 1
        spawn { copy_io(input, process_input, channel, close_dst: true) }
      else
        @input = process_input
      end
    end

    if needs_pipe?(output)
      process_output, fork_output = IO.pipe(write_blocking: true)
      if output
        @wait_count += 1
        spawn { copy_io(process_output, output, channel, close_src: true) }
      else
        @output = process_output
      end
    end

    if needs_pipe?(error)
      process_error, fork_error = IO.pipe(write_blocking: true)
      if error
        @wait_count += 1
        spawn { copy_io(process_error, error, channel, close_src: true) }
      else
        @error = process_error
      end
    end

    @pid = Process.fork_internal(run_hooks: false) do
      begin
        # File.umask(umask) if umask

        reopen_io(fork_input || input, STDIN, "r")
        reopen_io(fork_output || output, STDOUT, "w")
        reopen_io(fork_error || error, STDERR, "w")

        ENV.clear if clear_env
        env.try &.each do |key, val|
          if val
            ENV[key] = val
          else
            ENV.delete key
          end
        end

        Dir.cd(chdir) if chdir

        LibC.execvp(command, argv)
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

  protected def initialize(@pid)
    @waitpid_future = Event::SignalChildHandler.instance.waitpid(pid)
    @wait_count = 0
  end

  # See Process.kill
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

  # Closes any pipes to the child process.
  def close
    close_io @input
    close_io @output
    close_io @error
  end

  private def channel
    @channel ||= Channel(Exception?).new
  end

  private def needs_pipe?(io)
    io.nil? || (io.is_a?(IO) && !io.is_a?(IO::FileDescriptor))
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

  private def reopen_io(src_io, dst_io, mode)
    case src_io
    when IO::FileDescriptor
      src_io.blocking = true
      dst_io.reopen(src_io)
    when true
      # use same io as parent
      dst_io.blocking = true
    when false
      File.open("/dev/null", mode) do |file|
        dst_io.reopen(file)
      end
    else
      raise "unknown object type #{src_io}"
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
  status = Process.run(command, args, shell: true, input: true, output: true, error: true)
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
# `echo *` # => "LICENSE shard.yml Readme.md spec src\n"
# ```
def `(command) : String
  process = Process.new(command, shell: true, input: true, output: nil, error: true)
  output = process.output.gets_to_end
  status = process.wait
  $? = status
  output
end

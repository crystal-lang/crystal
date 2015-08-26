lib LibC
  fun execvp(file : Char*, argv : Char**) : Int
end

class Process
  # The standard io configuration of a process:
  #
  # * `nil`: use a pipe
  # * `false`: no IO (`/dev/null`)
  # * `true`: inherit from parent
  # * `IO`: use the given IO
  alias Stdio = Nil | Bool | IO
  alias Env = Nil | Hash(String, Nil) | Hash(String, String?) |  Hash(String, String)

  # Executes a process and waits for it to complete.
  #
  # By default the process is configured without input, output or error.
  def self.run(cmd : String, args = nil, env = nil : Env, clear_env = false : Bool, shell = false : Bool, input = false : Stdio, output = false : Stdio, error = false : Stdio, chdir = nil : String?) : Process::Status
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
  def self.run(cmd : String, args = nil, env = nil : Env, clear_env = false : Bool, shell = false : Bool, input = nil : Stdio, output = nil : Stdio, error = nil : Stdio, chdir = nil : String?)
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

  getter pid

  # A pipe to this process's input. Raises if a pipe wasn't asked when creating the process.
  getter! input

  # A pipe to this process's output. Raises if a pipe wasn't asked when creating the process.
  getter! output

  # A pipe to this process's error. Raises if a pipe wasn't asked when creating the process.
  getter! error

  # Creates a process, executes it, but doesn't wait for it to complete.
  #
  # To wait for it to finish, invoke `wait`.
  #
  # By default the process is configured without input, output or error.
  def initialize(command : String, args = nil, env = nil : Env, clear_env = false : Bool, shell = false : Bool, input = false : Stdio, output = false : Stdio, error = false : Stdio, chdir = nil : String?)
    cmd, argv = if shell
      raise "args not allowed with shell" if args
      {"/bin/sh", ["/bin/sh".to_unsafe, "-c".to_unsafe, command.to_unsafe, Pointer(UInt8).null]}
    else
      a = [command.to_unsafe]
      args.try &.each do |arg|
        a << arg.to_unsafe
      end
      a << Pointer(UInt8).null
      {command, a}
    end

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

    @pid = fork do
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

        Dir.chdir(chdir) if chdir

        LibC.execvp(cmd, argv)
      rescue ex
        ex.inspect(STDERR)
        STDERR.flush
      ensure
        LibC._exit 127
      end
    end

    fork_input.try &.close
    fork_output.try &.close
    fork_error.try &.close
  end

  # See Process.kill
  def kill sig = Signal::TERM
    Process.kill sig, @pid
  end

  # Waits for this process to complete and closes any pipes.
  def wait : Process::Status
    close_io @input # only closed when a pipe was created but not managed by copy_io

    @wait_count.times do
      ex = channel.receive
      raise ex if ex
    end

    exit_code = Process.waitpid(@pid)
    Status.new(exit_code)
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
    io.nil? || (io.is_a?(IO) && !io.is_a?(FileDescriptorIO))
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
    when FileDescriptorIO
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
    io.close if io && !io.closed?
  end
end

def system(command : String) : Bool
  status = Process.run(command, shell: true, input: true, output: true, error: true)
  $? = status
  status.success?
end

def `(command) : String
  process = Process.new(command, shell: true, input: true, output: nil, error: true)
  output = process.output.read
  status = process.wait
  $? = status
  output
end

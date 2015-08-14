lib LibC
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
end

class Process
  # The standard io configuration of a process:
  #
  # * `nil`: use a pipe
  # * `false`: no IO (`/dev/null`)
  # * `true`: inherit from parent
  # * `IO`: use the given IO
  alias Stdio = Nil | Bool | IO

  # Executes a process but doesn't wait for it to complete.
  #
  # To wait for it to finish, invoke `wait`.
  #
  # By default the process is configured without input, output or error.
  def self.run(cmd : String, args = nil, input = false : Stdio, output = false : Stdio, error = false : Stdio)
    new(cmd, args, input, output, error)
  end

  # Executes a process, yields the block, and then waits for it to finish.
  #
  # By default the process is configured to use pipes for input, output and error. These
  # will be closed automatically at the end of the block.
  #
  # Returns the block's value.
  def self.run(cmd : String, args = nil, input = nil : Stdio, output = nil : Stdio, error = nil : Stdio)
    process = run(cmd, args, input, output, error)
    value = yield process
    process.close
    $? = process.wait
    value
  end

  # A pipe to this process's input. Raises if a pipe wasn't asked when creating the process via `Process.run`.
  getter! input

  # A pipe to this process's output. Raises if a pipe wasn't asked when creating the process via `Process.run`.
  getter! output

  # A pipe to this process's error. Raises if a pipe wasn't asked when creating the process via `Process.run`.
  getter! error

  def initialize(command : String, args, input : Stdio, output : Stdio, error : Stdio)
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
        spawn { copy_io(input, process_input, channel) }
      else
        @input = process_input
      end
    end

    if needs_pipe?(output)
      process_output, fork_output = IO.pipe(write_blocking: true)
      if output
        @wait_count += 1
        spawn { copy_io(process_output, output, channel) }
      else
        @output = process_output
      end
    end

    if needs_pipe?(error)
      process_error, fork_error = IO.pipe(write_blocking: true)
      if error
        @wait_count += 1
        spawn { copy_io(process_error, error, channel) }
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

        # Dir.chdir(chdir) if chdir

        process_input.try &.close
        process_output.try &.close
        process_error.try &.close

        LibC.execvp(command, argv)
      rescue ex
        # TODO: print backtrace
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

  # Waits for this process to complete and returns a `Process::Status`.
  def wait
    @wait_count.times { channel.receive }

    exit_code = Process.waitpid(@pid)
    Status.new(exit_code)
  end

  # Closes any pipes to the child process
  def close
    close_io @input
    close_io @output
    close_io @error
  end

  private def channel
    @channel ||= Channel(Nil).new
  end

  private def needs_pipe?(io)
    io.nil? || (io.is_a?(IO) && !io.is_a?(FileDescriptorIO))
  end

  private def copy_io(src, dst, channel)
    return unless src.is_a?(IO) && dst.is_a?(IO)

    IO.copy(src, dst)
    dst.close
    channel.send nil
  end

  private def reopen_io(src_io, dst_io, mode)
    case src_io
    when FileDescriptorIO
      dst_io.reopen(src_io)
    when true
      # use same io as parent
    when false
      File.open("/dev/null", mode) do |file|
        dst_io.reopen(file)
      end
    else
      raise "unknown object type #{src_io}"
    end
  end

  private def close_io(io)
    io.close if io && !io.closed?
  end
end

def system(command : String)
  status = Process.run("/bin/sh", input: StringIO.new(command), output: true, error: true).wait
  $? = status
  status.success?
end

def `(command)
  process = Process.run("/bin/sh", input: StringIO.new(command), output: nil, error: true)
  output = process.output.read
  status = process.wait
  $? = status
  output
end

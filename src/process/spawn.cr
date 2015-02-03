lib LibC
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
  fun system(command : UInt8*) : Int32
  fun umask(mask : ModeT) : ModeT
end

module Process
  # Executes a command, replacing the current process with the executed one.
  # See Process.spawn for documentation.
  def self.exec(command, env = nil, input = nil, output = nil, error = nil)
    if env
      env.each do |key, value|
        if value.nil?
          ENV.delete(key.to_s)
        else
          ENV[key.to_s] = value.to_s
        end
      end
    end

    input.reopen(STDIN) if input

    output = "/dev/null" if output == false
    output = File.open(output, "r+") if output.is_a?(String)
    output.reopen(STDOUT) if output.is_a?(IO)

    error = "/dev/null" if error == false
    error = File.open(error, "r+") if error.is_a?(String)
    error.reopen(STDERR) if error.is_a?(IO)

    if command.is_a?(String)
      command = {"/bin/sh", "-c", command}
    end

    argv = command.map(&.cstr)
    argv << Pointer(UInt8).null

    if LibC.execvp(argv.first, argv.buffer) == -1
      raise Errno.new("Error while executing '#{command}'")
    end

    LibC.exit(0)
  end

  # Executes a command, then returns the PID of the child process. It won't wait
  # for the child process to terminate. It's exit status must be manually
  # collected using Process.waitpid to avoid zombie processes, that won't be
  # collected until the parent process exits.
  #
  # command can either be a String, that will run inside a shell, or an Array of
  # Strings that will be executed directly using the exec(2) family of functions,
  # starting with the name or path of the command to execute, followed by its arguments.
  #
  # env if expected to be a Hash. If a value is nil, the environment variable
  # will be removed, otherwise it will be set.
  #
  # You may write to the process' STDIN by passing a String or IO object as input.
  # You may also redirect STDOUT and STDERR by specifying output and error. They
  # both may be false to close the stream, a string to write to a file, or an IO
  # object.
  #
  # If pgroup is true, then the child process will run input it's own process group,
  # if it's a pgid (Int32), the child process will be moved to the specified
  # process group.
  def self.spawn(command, env = nil, input = nil, output = nil, error = nil, pgroup = nil, umask = nil)
    case input
    when String
      fork_input, process_input = IO.pipe
    when IO
      fork_input = input
    end

    pid = fork do
      process_input.close if process_input
      LibC.umask(umask) if umask

      case pgroup
      when true
        setsid
      when Int32
        setpgid(0, pgroup)
      end

      exec(command, env, fork_input, output, error)
      LibC.exit 127
    end

    if pid == -1
      raise Errno.new("Error while forking to exec '#{command}'")
    end

    if process_input
      process_input.print(input)
      process_input.close
    end

    pid
  end

  # Executes a command, waiting for it to return. Eventually returns true if the
  # command executed successfully, false otherwise. See Process.spawn for more
  # details.
  def self.system(command, env = nil, input = nil, output = nil, error = nil, pgroup = nil, umask = nil)
    pid = Process.spawn(command, env, input, output, error, pgroup, umask)
    status = Process::Status.new(pid)
    status.exit = Process.waitpid(pid)
    Process::Status.last = status
    status.success?
  end
end

def system(command, env = nil, input = nil, output = nil, error = nil, pgroup = nil, umask = nil)
  Process.system(command, env, input, output, error, pgroup, umask)
end

# Executes a command, waiting for it to return, then returns the output of the
# command. See Process.spawn for more details.
def `(command)
  IO.pipe do |read, write|
    pid = Process.spawn(command, output: write)
    status = Process::Status.new(pid)
    write.close

    output = StringIO.new
    buffer :: UInt8[2048]

    loop do
      ios = IO.select({read})

      if ios.includes?(read)
        bytes = read.read(buffer.to_slice)
        if bytes == 0
          read.close
          break
        end
        output.write(buffer.to_slice, bytes)
      end
    end

    status.exit = Process.waitpid(pid)
    status.output = output
    Process::Status.last = status

    output.to_s
  end
end

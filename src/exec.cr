lib C
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
  fun pipe(filedes : Int32[2]*) : Int32
end

struct ProcessStatus
  property pid
  property status
  property input
  property output

  def initialize(@pid)
  end
end

def exec(command, args = nil, output = nil)
  argv = [command.cstr]
  if args
    args.each do |arg|
      argv << arg.cstr
    end
  end
  argv << Pointer(UInt8).null

  if output == true
    C.pipe(out output_pipe)
  end

  pid = fork do
    if output == false
      null = C.open("/dev/null", C::O_RDWR)
      C.dup2(null, STDOUT.fd)
    elsif output_pipe
      C.dup2(output_pipe[1], STDOUT.fd)
    end

    C.execvp(command, argv.buffer)
    C.exit 127
  end

  if pid == -1
    raise Errno.new("Error executing system command '#{command}'")
  end

  status = ProcessStatus.new(pid)

  if output && output_pipe
    C.close(output_pipe[1])
    output_io = FileDescriptorIO.new(output_pipe[0])
    status.output = status_output = [] of String
    while line = output_io.gets
      status_output << line.chomp
    end
    output_io.close
  end

  C.waitpid(pid, out status_code, 0)
  status.status = status_code >> 8
  status
end

lib LibC
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
end

def Process.run(command, args = nil, output = nil : IO | Bool, input = nil : String | IO)
  argv = [command.cstr]
  if args
    args.each do |arg|
      argv << arg.cstr
    end
  end
  argv << Pointer(UInt8).null

  if output
    process_output, fork_output = IO.pipe
  end

  if input
    fork_input, process_input = IO.pipe
  end

  pid = fork do
    if output == false
      null = File.new("/dev/null", "r+")
      null.reopen(STDOUT)
    elsif fork_output
      fork_output.reopen(STDOUT)
    end

    if process_input && fork_input
      process_input.close
      fork_input.reopen(STDIN)
    end

    LibC.execvp(command, argv.buffer)
    LibC.exit 127
  end

  if pid == -1
    raise Errno.new("Error executing system command '#{command}'")
  end

  status = Process::Status.new(pid)

  if input
    process_input = process_input.not_nil!
    fork_input.not_nil!.close

    case input
    when String
      process_input.print input
      process_input.close
      process_input = nil
    when IO
      input_io = input
    end
  end

  if output
    fork_output.not_nil!.close

    case output
    when true
      status_output = StringIO.new
    when IO
      status_output = output
    end
  end

  while process_input || process_output
    wios = nil
    rios = nil

    if process_input
      wios = {process_input}
    end

    if process_output
      rios = {process_output}
    end

    buffer :: UInt8[2048]

    ios = IO.select(rios, wios)
    next unless ios

    if process_input && ios.includes? process_input
      bytes = input_io.not_nil!.read(buffer.to_slice)
      if bytes == 0
        process_input.close
        process_input = nil
      else
        process_input.write(buffer.to_slice, bytes)
      end
    end

    if process_output && ios.includes? process_output
      bytes = process_output.read(buffer.to_slice)
      if bytes == 0
        process_output.close
        process_output = nil
      else
        status_output.not_nil!.write(buffer.to_slice, bytes)
      end
    end
  end

  status.exit = Process.waitpid(pid)

  if output == true
    status.output = status_output.to_s
  end

  Process::Status.last = status

  status
end

def system(command : String)
  status = Process.run("/bin/sh", input: command, output: STDOUT)
  # $? = status
  status.success?
end

def `(command)
  status = Process.run("/bin/sh", input: command, output: true)
  # $? = status
  status.output.not_nil!
end

lib LibC
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
end

def Process.run(command, args = nil, output = nil : IO | Bool | Symbol, error = nil : IO | Bool | Symbol, input = nil : String | IO)
  argv = [command.cstr]
  if args
    args.each do |arg|
      argv << arg.cstr
    end
  end
  argv << Pointer(UInt8).null

  if output.is_a?(Symbol) && output != :error
    raise ArgumentError.new("output must be an true, false, an IO or :error, not #{error.inspect}")
  end

  if error.is_a?(Symbol) && error != :output
    raise ArgumentError.new("error must be an true, false, an IO or :output, not #{error.inspect}")
  end

  if output == :error && error == :output
    raise ArgumentError.new("Can't redirect error to output while output is redirected to error")
  end

  if output == :error && error == false
    output = false
  end

  if error == :output && output == false
    error = false
  end

  if output
    process_output, fork_output = IO.pipe
  end

  if error
    process_error, fork_error = IO.pipe
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

    if error == false
      null = File.new("/dev/null", "r+")
      null.reopen(STDERR)
    elsif fork_error
      fork_error.reopen(STDERR)
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

  if error
    fork_error.not_nil!.close

    case error
    when true
      status_error = StringIO.new
    when IO
      status_error = error
    end
  end

  while process_input || process_output || process_error
    wios = nil
    rios = nil

    if process_input
      wios = {process_input}
    end

    if process_output && process_error
      rios = {process_output, process_error}
    elsif process_output
      rios = {process_output}
    elsif process_error
      rios = {process_error}
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
      elsif output == :error
        if error.nil?
          STDERR.write(buffer.to_slice, bytes)
        else
          status_error.not_nil!.write(buffer.to_slice, bytes)
        end
      else
        status_output.not_nil!.write(buffer.to_slice, bytes)
      end
    end

    if process_error && ios.includes? process_error
      bytes = process_error.read(buffer.to_slice)
      if bytes == 0
        process_error.close
        process_error = nil
      elsif error == :output
        if output.nil?
          STDOUT.write(buffer.to_slice, bytes)
        else
          status_output.not_nil!.write(buffer.to_slice, bytes)
        end
      else
        status_error.not_nil!.write(buffer.to_slice, bytes)
      end
    end
  end

  status.exit = Process.waitpid(pid)

  if output == true
    status.output = status_output.to_s
  end

  if error == true
    status.error = status_error.to_s
  end

  Process::Status.last = status

  status
end

def system(command : String)
  Process.run("/bin/sh", input: command, output: STDOUT).success?
end

def `(command)
  Process.run("/bin/sh", input: command, output: true).output.not_nil!
end

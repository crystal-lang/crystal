lib LibC
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
end

module Process
  def self.run(command, args = nil, output = nil : IO | Bool | Symbol, error = nil : IO | Bool | Symbol, input = nil : String | IO)
    validate_arguments(output, error)

    output = false if output == :error && error == false
    error  = false if error == :output && output == false


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
      redirect(output,        fork_output, STDOUT)
      redirect(error,         fork_error,  STDERR)
      redirect(process_input, fork_input,  STDIN)

      process_input.close if process_input && fork_input

      LibC.execvp(command, argv_buffer(command, args))
      LibC.exit 127
    end

    if pid == -1
      raise Errno.new("Error executing system command '#{command}'")
    end

    process_input, input_io = prepare_write(input, process_input, fork_input)

    status_output = prepare_read(output, fork_output)
    status_error  = prepare_read(error,  fork_error)

    while process_input || process_output || process_error
      wios = if process_input
         {process_input}
      end

      rios = if process_output && process_error
        {process_output, process_error}
      elsif process_output
        {process_output}
      elsif process_error
        {process_error}
      end

      ios = IO.select(rios, wios)

      next unless ios

      if process_input && ios.includes? process_input
        process_input = read_data(input_io, process_input)
      end

      if process_output && ios.includes? process_output
        process_output = write_data(
          process_output, output, error, status_output, status_error, STDERR
        )
      end

      if process_error && ios.includes? process_error
        process_error = write_data(
          process_error, error, output, status_error, status_output, STDOUT
        )
      end
    end

    status = Process::Status.new(pid)
    status.exit = Process.waitpid(pid)
    status.output = status_output.to_s if output == true
    status.error  = status_error.to_s  if error  == true

    Process::Status.last = status

    status
  end

  private def self.validate_arguments(output, error)
    if output.is_a?(Symbol) && output != :error
      raise ArgumentError.new("output must be an true, false, an IO or :error, not #{error.inspect}")
    end

    if error.is_a?(Symbol) && error != :output
      raise ArgumentError.new("error must be an true, false, an IO or :output, not #{error.inspect}")
    end

    if output == :error && error == :output
      raise ArgumentError.new("Can't redirect error to output while output is redirected to error")
    end
  end

  private def self.redirect(flag, where, what)
    if flag == false
      null = File.new("/dev/null", "r+")
      null.reopen(what)
    elsif where
      where.reopen(what)
    end
  end

  private def self.argv_buffer(command, args)
    argv = [command.cstr]
    if args
      args.each do |arg|
        argv << arg.cstr
      end
    end
    argv << Pointer(UInt8).null
    argv.buffer
  end


  private def self.prepare_write(input, process_input, fork_input)
    return {nil, nil} unless input

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

    {process_input, input_io}
  end

  private def self.prepare_read(output, fork_output)
    return unless output

    fork_output.not_nil!.close

    case output
    when true
      StringIO.new
    when IO
      output
    end
  end

  private def self.write_data(io, flag, other, status, status_other, fallback)
    buffer :: UInt8[2048]

    bytes = io.read(buffer.to_slice)
    output = nil

    if bytes == 0
      io.close
      io = nil
    elsif flag == :output
      output = other.nil? ? fallback : status_other
    else
      output = status
    end

    output.write(buffer.to_slice, bytes) if output

    io
  end

  private def self.read_data(io, other)
    buffer :: UInt8[2048]

    bytes = io.not_nil!.read(buffer.to_slice)
    if bytes == 0
      other.close
      other = nil
    else
      other.write(buffer.to_slice, bytes)
    end

    other
  end
end

def system(command : String)
  Process.run("/bin/sh", input: command, output: STDOUT).success?
end

def `(command)
  Process.run("/bin/sh", input: command, output: true).output.not_nil!
end

# Executes a command, waits for it to exit and returns a Process::Status object.
#
# Output is captured in status.output if the output parameter is true
#
# See Process.spawn for arguments
def Process.run(command, args = nil, output = nil : IO | Bool, input = nil : String | IO | Bool, chdir = nil : String)
  case input
  when FileDescriptorIO, Bool, nil
    # passed to spawn
  when IO, String
    fork_input, process_input = IO.pipe(read_blocking: true)
    fork_input.close_on_exec = true
    process_input.close_on_exec = true
  else
    raise "unknown type #{input.inspect}"
  end

  case output
  when FileDescriptorIO, false, nil
    # passed to spawn
  when IO, String, true
    process_output, fork_output = IO.pipe(write_blocking: true)
    process_output.close_on_exec = true
    fork_output.close_on_exec = true
  else
    raise "unknown type #{input.inspect}"
  end

  pid = spawn(command, args, input: (fork_input || input), output: (fork_output || output), chdir: chdir) do
    process_input.close if process_input
    process_output.close if process_output
  end

  status = Process::Status.new(pid)

  if process_input
    fork_input.not_nil!.close

    case input
    when String, StringIO
      process_input.print input.to_s
      process_input.close
      process_input = nil
    when IO # not FileDescriptorIO
      input_io = input
    end
  end

  if process_output
    fork_output.not_nil!.close

    case output
    when true
      status_output = StringIO.new
    when IO # not FileDescriptorIO
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

  $? = status

  status
end

def system(command : String)
  status = Process.run("/bin/sh", input: command, output: STDOUT)
  $? = status
  status.success?
end

def `(command)
  status = Process.run("/bin/sh", input: command, output: true)
  $? = status
  status.output.not_nil!
end

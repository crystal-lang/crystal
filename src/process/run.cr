# Executes a command, waits for it to exit and returns a Process::Status object.
#
# See Process.spawn for arguments
#   output|error is captured in status.output if the parameter is nil
#   StringIO objects may also be used for input|output|error unlike popen or spawn.
def Process.run(command, args = nil, input = true : Nil | IO | StringIO | Bool, output = nil : Nil | IO | StringIO | Bool, error = true : Nil | IO | StringIO | Bool, chdir = nil : String?)
  case input
  when FileDescriptorIO, Bool, nil
    # passed to popen
    popen_input = input
    copy_input = nil
  when IO, StringIO
    # redirected to IO provided
    popen_input = nil
    copy_input = input
  end

  case output
  when FileDescriptorIO, Bool
    # passed to popen
    popen_output = output
    copy_output = nil
  when IO, StringIO, nil
    # redirected to IO provided
    popen_output = nil
    copy_output = output || StringIO.new
  end

  case error
  when FileDescriptorIO, Bool
    # passed to popen
    popen_error = error
    copy_error = nil
  when IO, StringIO, nil
    # redirected to IO provided
    popen_error = nil
    copy_error = error
  end

  status = popen(command, args, input: popen_input, output: popen_output, error: popen_error, chdir: chdir)

  input_copy = -> { io_copy("input", copy_input, status.input, true) }
  output_copy = -> { io_copy("output", status.output, copy_output) }
  error_copy = -> { io_copy("error", status.error, copy_error) }
  parallel(input_copy.call, output_copy.call, error_copy.call)

  status.close

  status.output = copy_output if copy_output
  status.error = copy_error if copy_error

  $? = status

  status
end

private def io_copy msg, src, dst, close_dst = false
  return true unless src.is_a?(IO) && dst.is_a?(IO)
  IO.copy(src, dst)
  dst.close if close_dst
  true # not used.  compiler doesn't like nil return
end

def system(command : String)
  status = Process.run("/bin/sh", { "-c", command }, output: STDOUT, error: STDERR)
  $? = status
  status.success?
end

def `(command)
  status = Process.run("/bin/sh", { "-c", command }, output: nil, error: STDERR)
  $? = status
  status.output.not_nil!.to_s
end

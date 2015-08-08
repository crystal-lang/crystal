# Executes a command and returns a Process::Status object which contains pipes to stdin/stdout/stderr depending on the arguments passed.
#
# See Process.spawn for arguments
#   Passing nil to input|output|error creates pipes that may be used to communicate with the child.  The pipes are returned in the status object.
def Process.popen(command, args = nil, input = nil : Nil | FileDescriptorIO | Bool, output = nil : Nil | FileDescriptorIO | Bool, error = nil : Nil | FileDescriptorIO | Bool, chdir = nil : String?)
  case input
  when FileDescriptorIO, Bool
    # passed to spawn
  when nil
    fork_input, process_input = IO.pipe(read_blocking: true)
    fork_input.close_on_exec = true
    process_input.close_on_exec = true
  else
    raise "unknown type #{input.inspect}"
  end

  case output
  when FileDescriptorIO, Bool
    # passed to spawn
  when nil
    process_output, fork_output = IO.pipe(write_blocking: true)
    process_output.close_on_exec = true
    fork_output.close_on_exec = true
  else
    raise "unknown type #{error.inspect}"
  end

  case error
  when FileDescriptorIO, Bool
    # passed to spawn
  when nil
    process_error, fork_error = IO.pipe(write_blocking: true)
    process_error.close_on_exec = true
    fork_error.close_on_exec = true
  else
    raise "unknown type #{error.inspect}"
  end

  status = spawn(command, args, input: (fork_input || input), output: (fork_output || output), error: (fork_error || error), chdir: chdir) do
    process_input.close if process_input
    process_output.close if process_output
    process_error.close if process_error
  end

  fork_input.close if fork_input
  fork_output.close if fork_output
  fork_error.close if fork_error

  status.input = process_input || input
  status.output = process_output || output
  status.error = process_error || error
  status.manage_input = !!process_input
  status.manage_output = !!process_output
  status.manage_error = !!process_error

  status
end

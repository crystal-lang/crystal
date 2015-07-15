lib LibC
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
end

# Executes a command and returns it's pid.
#
# input|output|error
#   nil -> share parent stdio
#   false -> reopen /dev/null in child
#   IO -> filedescriptor of object is reopened
#
# TODO: Missing pgroup, env, unsetenv_others, pgroup, new_pgroup (windows), :rlimit_..., close_others, file number redirection
def Process.spawn(command, args = nil, input = nil, output = nil, error = nil, chdir = nil, umask = nil)
  spawn(command, args, input, output, error, chdir, umask) { nil }
end

# :nodoc:
def Process.spawn(command, args = nil, input = nil : Nil | Bool | FileDescriptorIO, output = nil : Nil | Bool | FileDescriptorIO, error = nil : Nil | Bool | FileDescriptorIO, chdir = nil : Nil | String, umask = nil : Nil | UInt16, &block)
  argv = [command.cstr]
  if args
    args.each do |arg|
      argv << arg.cstr
    end
  end
  argv << Pointer(UInt8).null

  pid = fork do
# TODO: wrap in begin/ensure and use _exit, not exit
    File.umask(umask) if umask

    reopen_io(input, STDIN, "r")
    reopen_io(output, STDOUT, "w")
    reopen_io(error, STDERR, "w")

    Dir.chdir(chdir) if chdir

    yield # close file descriptors, etc.  remove when close_others is implemented.

    LibC.execvp(command, argv.buffer)
    LibC.exit 127
  end

  pid
end

private def reopen_io srcio, dstio, mode
  case srcio
  when FileDescriptorIO
    dstio.reopen(srcio)
  when false
    File.open("/dev/null", mode) do |file|
      dstio.reopen(file)
    end
  when true, nil
    # use same io as parent
  else
    raise "unknown object type #{srcio}"
  end
end

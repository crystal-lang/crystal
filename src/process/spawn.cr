lib LibC
  fun execvp(file : UInt8*, argv : UInt8**) : Int32
end

# Executes a command and returns it's pid.
#
# input|output|error
#   true -> share parent stdio
#   false -> reopen /dev/null in child
#   IO -> filedescriptor of object is reopened in child
#
# TODO: Missing pgroup, env, unsetenv_others, pgroup, new_pgroup (windows), :rlimit_..., close_others, file number redirection
def Process.spawn(command, args = nil, input = true, output = true, error = true, chdir = nil, umask = nil)
  spawn(command, args, input, output, error, chdir, umask) { nil }
end

# :nodoc:
def Process.spawn(command, args = nil, input = true : Bool | FileDescriptorIO, output = true : Bool | FileDescriptorIO, error = true : Bool | FileDescriptorIO, chdir = nil : String?, umask = nil : UInt16?, &block)
  argv = [command.cstr]
  if args
    args.each do |arg|
      argv << arg.cstr
    end
  end
  argv << Pointer(UInt8).null

  pid = fork do
    begin
      File.umask(umask) if umask

      reopen_io(input, STDIN, "r")
      reopen_io(output, STDOUT, "w")
      reopen_io(error, STDERR, "w")

      Dir.chdir(chdir) if chdir

      yield # close file descriptors, etc.  remove when close_others is implemented.

      LibC.execvp(command, argv.buffer)
    rescue ex
# TODO: print backtrace
      STDERR.puts ex.inspect
    ensure
      LibC._exit 127
    end
  end

  Process::Status.new(pid)
end

private def reopen_io srcio, dstio, mode
  case srcio
  when FileDescriptorIO
    dstio.reopen(srcio)
  when true
    # use same io as parent
  when false
    File.open("/dev/null", mode) do |file|
      dstio.reopen(file)
    end
  else
    raise "unknown object type #{srcio}"
  end
end

require "c/signal"
require "c/stdlib"
require "c/sys/resource"
require "c/unistd"

class Process
  protected def wait_system
    Crystal::SignalChildHandler.wait(@waitpid, @pid)
  end

  protected def self.exit_system(status = 0) : NoReturn
    LibC.exit(status)
  end

  protected def self.pid_system : Int64
    LibC.getpid.to_i64
  end

  protected def self.ppid_system : Int64
    LibC.getppid.to_i64
  end

  protected def exists_system?
    Process.exists_system?(@pid)
  end

  protected def self.exists_system?(pid : Int64)
    ret = LibC.kill(pid, 0)
    return true if ret == 0
    return false if Errno.value == Errno::ESRCH
    raise Errno.new("kill")
  end

  protected def pgid_system : Int64
    Process.pgid_system(@pid)
  end

  protected def self.pgid_system(pid : Int64) : Int64
    ret = LibC.getpgid(pid)
    raise Errno.new("getpgid") if ret < 0
    ret.to_i64
  end

  protected def signal_system(signal : Signal)
    ret = LibC.kill(@pid, signal.value)
    raise Errno.new("kill") if ret < 0
  end

  protected def create_and_exec(command : String, args : (Array | Tuple)?, env : Env?, clear_env : Bool, fork_input : IO::FileDescriptor, fork_output : IO::FileDescriptor, fork_error : IO::FileDescriptor, chdir : String?)
    reader_pipe, writer_pipe = IO.pipe

    pid = create_and_exec_impl(command, args, env, clear_env, fork_input, fork_output, fork_error, chdir, reader_pipe, writer_pipe)
    writer_pipe.close
    bytes = uninitialized UInt8[4]
    if reader_pipe.read(bytes.to_slice) == 4
      errno = IO::ByteFormat::SystemEndian.decode(Int32, bytes.to_slice)
      message_size = reader_pipe.read_bytes(Int32)
      if message_size > 0
        message = String.build(message_size) { |io| IO.copy(reader_pipe, io, message_size) }
      end
      reader_pipe.close
      raise Errno.new(message, errno)
    end
    reader_pipe.close
    pid
  end

  protected def create_and_exec_impl(command : String, args : (Array | Tuple)?, env : Env?, clear_env : Bool, fork_input : IO::FileDescriptor, fork_output : IO::FileDescriptor, fork_error : IO::FileDescriptor, chdir : String?, reader_pipe : IO::FileDescriptor, writer_pipe : IO::FileDescriptor)
    if pid = Process.fork_internal(will_exec: true)
      return pid
    end
    begin
      reader_pipe.close
      writer_pipe.close_on_exec = true
      Process.exec_internal(command, args, env, clear_env, fork_input, fork_output, fork_error, chdir)
    rescue ex : Errno
      writer_pipe.write_bytes(ex.errno)
      writer_pipe.write_bytes(ex.message.try(&.bytesize) || 0)
      writer_pipe << ex.message
      writer_pipe.close
    rescue ex
      ex.inspect_with_backtrace STDERR
      STDERR.flush
    ensure
      LibC._exit 127
    end
  end

  protected def self.fork_system : Process
    {% raise("Process fork is unsupported with multithread mode") if flag?(:preview_mt) %}
    if pid = fork_internal(will_exec: false)
      return new pid
    end
    begin
      yield
      LibC._exit 0
    rescue ex
      ex.inspect_with_backtrace STDERR
      STDERR.flush
      LibC._exit 1
    ensure
      LibC._exit 254 # not reached
    end
  end

  protected def self.fork_system : Process?
    {% raise("Process fork is unsupported with multithread mode") if flag?(:preview_mt) %}
    if pid = fork_internal(will_exec: false)
      new pid
    end
  end

  ORIGINAL_STDIN  = IO::FileDescriptor.new(0, blocking: true)
  ORIGINAL_STDOUT = IO::FileDescriptor.new(1, blocking: true)
  ORIGINAL_STDERR = IO::FileDescriptor.new(2, blocking: true)

  protected def self.reopen_io(src_io : IO::FileDescriptor, dst_io : IO::FileDescriptor)
    src_io = to_real_fd(src_io)
    dst_io.reopen(src_io)
    dst_io.blocking = true
    dst_io.close_on_exec = false
  end

  protected def self.to_real_fd(fd : IO::FileDescriptor)
    case fd
    when STDIN  then ORIGINAL_STDIN
    when STDOUT then ORIGINAL_STDOUT
    when STDERR then ORIGINAL_STDERR
    else             fd
    end
  end

  protected def self.exec_internal(command, args : (Array | Tuple)?, env, clear_env, input, output, error, chdir) : NoReturn
    reopen_io(input, ORIGINAL_STDIN)
    reopen_io(output, ORIGINAL_STDOUT)
    reopen_io(error, ORIGINAL_STDERR)

    ENV.clear if clear_env
    env.try &.each do |key, val|
      if val
        ENV[key] = val
      else
        ENV.delete key
      end
    end

    Dir.cd(chdir) if chdir

    argv = [command.check_no_null_byte.to_unsafe]
    args.try &.each do |arg|
      argv << arg.check_no_null_byte.to_unsafe
    end
    argv << Pointer(UInt8).null

    LibC.execvp(command, argv)

    error_message = String.build do |io|
      io << "execvp ("
      command.inspect_unquoted(io)
      args.try &.each do |arg|
        io << ' '
        arg.inspect(io)
      end
      io << ")"
    end
    raise Errno.new(error_message)
  end

  protected def self.prepare_shell_system(command, args)
    command = %(#{command} "${@}") unless command.includes?(' ')
    shell_args = ["-c", command, "--"]

    if args
      unless command.includes?(%("${@}"))
        raise ArgumentError.new(%(can't specify arguments in both, command and args without including "${@}" into your command))
      end

      {% if flag?(:freebsd) %}
        shell_args << ""
      {% end %}

      shell_args.concat(args)
    end

    command = "/bin/sh"
    {command, shell_args}
  end

  # :nodoc:
  protected def self.fork_internal(*, will_exec : Bool) : Int64?
    newmask = uninitialized LibC::SigsetT
    oldmask = uninitialized LibC::SigsetT

    LibC.sigfillset(pointerof(newmask))
    ret = LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(newmask), pointerof(oldmask))
    raise Errno.new("Failed to disable signals") unless ret == 0

    case pid = LibC.fork
    when 0
      # child:
      pid = nil
      if will_exec
        # reset signal handlers, then sigmask (inherited on exec):
        Crystal::Signal.after_fork_before_exec
        LibC.sigemptyset(pointerof(newmask))
        LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(newmask), nil)
      else
        {% unless flag?(:preview_mt) %}
          ::Process.after_fork_child_callbacks.each(&.call)
        {% end %}
        LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
      end
    when -1
      # error:
      errno = Errno.value
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
      raise Errno.new("fork", errno)
    else
      # parent:
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
    end

    pid.try &.to_i64
  end

  protected def close_system
  end

  protected def self.chroot_system(path : String) : Nil
    path.check_no_null_byte
    if LibC.chroot(path) != 0
      raise Errno.new("Failed to chroot")
    end

    if LibC.chdir("/") != 0
      errno = Errno.new("chdir after chroot failed")
      errno.callstack = CallStack.new
      errno.inspect_with_backtrace(STDERR)
      abort("Unresolvable state, exiting...")
    end
  end

  protected def self.times_system : Tms
    LibC.getrusage(LibC::RUSAGE_SELF, out usage)
    LibC.getrusage(LibC::RUSAGE_CHILDREN, out child)

    Tms.new(
      usage.ru_utime.tv_sec.to_f64 + usage.ru_utime.tv_usec.to_f64 / 1e6,
      usage.ru_stime.tv_sec.to_f64 + usage.ru_stime.tv_usec.to_f64 / 1e6,
      child.ru_utime.tv_sec.to_f64 + child.ru_utime.tv_usec.to_f64 / 1e6,
      child.ru_stime.tv_sec.to_f64 + child.ru_stime.tv_usec.to_f64 / 1e6,
    )
  end
end

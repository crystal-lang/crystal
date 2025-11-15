require "c/signal"
require "c/stdlib"
require "c/sys/resource"
require "c/unistd"
require "c/limits"
require "crystal/rw_lock"
require "file/error"

struct Crystal::System::Process
  getter pid : LibC::PidT

  def initialize(@pid : LibC::PidT)
    @channel = Crystal::System::SignalChildHandler.wait(@pid)
  end

  def release
  end

  def wait
    @channel.receive
  end

  def exists?
    !@channel.closed? && Crystal::System::Process.exists?(@pid)
  end

  def terminate(*, graceful)
    Crystal::System::Process.signal(@pid, graceful ? LibC::SIGTERM : LibC::SIGKILL)
  end

  def self.exit(status)
    LibC.exit(status)
  end

  def self.pid
    LibC.getpid
  end

  def self.pgid
    ret = LibC.getpgid(0)
    raise RuntimeError.from_errno("getpgid") if ret < 0
    ret
  end

  def self.pgid(pid)
    # Disallow users from depending on ppid(0) instead of `pgid`
    raise RuntimeError.from_os_error("getpgid", Errno::EINVAL) if pid == 0

    ret = LibC.getpgid(pid)
    raise RuntimeError.from_errno("getpgid") if ret < 0
    ret
  end

  def self.ppid
    LibC.getppid
  end

  def self.signal(pid, signal)
    ret = LibC.kill(pid, signal)
    raise RuntimeError.from_errno("kill") if ret < 0
  end

  @[Deprecated("Use `#on_terminate` instead")]
  def self.on_interrupt(&handler : ->) : Nil
    ::Signal::INT.trap { |_signal| handler.call }
  end

  def self.on_terminate(&handler : ::Process::ExitReason ->) : Nil
    sig_handler = Proc(::Signal, Nil).new do |signal|
      int_type = case signal
                 when .int?
                   ::Process::ExitReason::Interrupted
                 when .hup?
                   ::Process::ExitReason::TerminalDisconnected
                 when .term?
                   ::Process::ExitReason::SessionEnded
                 else
                   ::Process::ExitReason::Interrupted
                 end
      handler.call int_type

      # ignore prevents system defaults and clears registered interrupts
      # hence we need to re-register
      signal.ignore
      Process.on_terminate &handler
    end
    ::Signal::INT.trap &sig_handler
    ::Signal::HUP.trap &sig_handler
    ::Signal::TERM.trap &sig_handler
  end

  def self.ignore_interrupts! : Nil
    ::Signal::INT.ignore
  end

  def self.restore_interrupts! : Nil
    ::Signal::INT.reset
  end

  def self.start_interrupt_loop : Nil
    # do nothing; `Crystal::System::Signal.start_loop` takes care of this
  end

  def self.debugger_present? : Bool
    {% if flag?(:linux) %}
      ::File.each_line("/proc/self/status") do |line|
        if tracer_pid = line.lchop?("TracerPid:").try(&.to_i?)
          return true if tracer_pid != 0
        end
      end
    {% end %}

    # TODO: [Darwin](https://stackoverflow.com/questions/2200277/detecting-debugger-on-mac-os-x)
    # TODO: other BSDs
    # TODO: [Solaris](https://docs.oracle.com/cd/E23824_01/html/821-1473/proc-4.html)
    false
  end

  def self.exists?(pid)
    ret = LibC.kill(pid, 0)
    if ret == 0
      true
    else
      case Errno.value
      when Errno::EPERM
        true
      when Errno::ESRCH
        false
      else
        raise RuntimeError.from_errno("kill")
      end
    end
  end

  def self.times
    LibC.getrusage(LibC::RUSAGE_SELF, out usage)
    LibC.getrusage(LibC::RUSAGE_CHILDREN, out child)

    ::Process::Tms.new(
      usage.ru_utime.tv_sec.to_f64 + usage.ru_utime.tv_usec.to_f64 / 1e6,
      usage.ru_stime.tv_sec.to_f64 + usage.ru_stime.tv_usec.to_f64 / 1e6,
      child.ru_utime.tv_sec.to_f64 + child.ru_utime.tv_usec.to_f64 / 1e6,
      child.ru_stime.tv_sec.to_f64 + child.ru_stime.tv_usec.to_f64 / 1e6,
    )
  end

  # The RWLock is trying to protect against file descriptors leaking to
  # sub-processes.
  #
  # There is a race condition in the POSIX standard between the creation of a
  # file descriptor (`accept`, `dup`, `open`, `pipe`, `socket`) and setting the
  # `FD_CLOEXEC` flag with `fcntl`. During the time window between those two
  # syscalls, another thread may fork the process and exec another process,
  # which will leak the file descriptor to that process.
  #
  # Most systems have long implemented non standard syscalls that prevent the
  # race condition, except for Darwin that implements `O_CLOEXEC` but doesn't
  # implement `SOCK_CLOEXEC` nor `accept4`, `dup3` or `pipe2`.
  #
  # NOTE: there may still be some potential leaks (e.g. calling `accept` on a
  #       blocking socket).
  #
  # `SOCK_CLOEXEC` and `accept4` are defined in `c/sys/socket.cr` which is only
  # included when using sockets. The absence of `LibC.socket` indicates that
  # we're not using sockets.
  {% if (LibC.has_constant?(:SOCK_CLOEXEC) && (LibC.has_method?(:accept4)) || !LibC.has_method?(:socket)) && LibC.has_method?(:dup3) && LibC.has_method?(:pipe2) %}
    # we don't implement .lock_read so compilation will fail if we need to
    # support another case, instead of silently skipping the rwlock!

    def self.lock_write(&)
      yield
    end
  {% else %}
    @@rwlock = Crystal::RWLock.new

    def self.lock_read(&)
      @@rwlock.read_lock
      begin
        yield
      ensure
        @@rwlock.read_unlock
      end
    end

    def self.lock_write(&)
      @@rwlock.write_lock
      begin
        yield
      ensure
        @@rwlock.write_unlock
      end
    end
  {% end %}

  def self.system_fork(*, will_exec : Bool, &)
    newmask = uninitialized LibC::SigsetT
    oldmask = uninitialized LibC::SigsetT

    # block signals while we fork, so the child process won't forward signals it
    # may receive to the parent through the signal pipe, but make sure to not
    # block stop-the-world signals as it appears to create deadlocks in glibc
    # for example; this is safe because these signal handlers musn't be
    # registered through `Signal.trap` but directly through `sigaction`.
    LibC.sigfillset(pointerof(newmask))
    LibC.sigdelset(pointerof(newmask), System::Thread.sig_suspend)
    LibC.sigdelset(pointerof(newmask), System::Thread.sig_resume)
    ret = LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(newmask), pointerof(oldmask))
    raise RuntimeError.from_errno("Failed to disable signals") unless ret == 0

    case pid = lock_write { LibC.fork }
    when 0
      # child:
      pid = nil

      # after fork callback
      yield

      if will_exec
        # reset sigmask (inherited on exec)
        LibC.sigemptyset(pointerof(newmask))
        LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(newmask), nil)
      else
        # restore sigmask
        LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
      end
    when -1
      # error:
      errno = Errno.value
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
      raise RuntimeError.from_os_error("fork", errno)
    else
      # parent:
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)
    end

    pid
  end

  # Only used by deprecated `::Process.fork`
  def self.fork
    {% raise("Process fork is unsupported with multithreaded mode") if flag?(:preview_mt) %}

    system_fork(will_exec: false) do
      ::Process.after_fork_child_callbacks.each(&.call)
    end
  end

  # Duplicates the current process.
  # Returns a `Process` representing the new child process in the current process
  # and `nil` inside the new child process.
  # Only used by deprecated `::Process.fork(&)` and compiler `fork_codegen`
  def self.fork(&)
    pid = fork
    return pid if pid

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

  def self.spawn(command, args, shell, env, clear_env, input, output, error, chdir)
    prepared_args = prepare_args(command, args, shell)

    r, w = FileDescriptor.system_pipe

    envp = Env.make_envp(env, clear_env)

    pid = system_fork(will_exec: true) do
      Crystal::System::Signal.after_fork_before_exec
    end

    if !pid
      LibC.close(r)
      begin
        self.try_replace(prepared_args, envp, input, output, error, chdir)
        byte = 1_u8
        errno = Errno.value.to_i32
        FileDescriptor.write_fully(w, pointerof(byte))
        FileDescriptor.write_fully(w, pointerof(errno))
      rescue ex
        byte = 0_u8
        message = ex.inspect_with_backtrace
        FileDescriptor.write_fully(w, pointerof(byte))
        FileDescriptor.write_fully(w, message.to_slice)
      ensure
        LibC.close(w)
        LibC._exit 127
      end
    end

    LibC.close(w)
    reader_pipe = IO::FileDescriptor.new(r)

    begin
      case reader_pipe.read_byte
      when nil
        # Pipe was closed, no error
      when 0
        # Error message coming
        message = reader_pipe.gets_to_end
        raise RuntimeError.new("Error executing process: '#{prepared_args[0]}': #{message}")
      when 1
        # Errno coming
        # can't use IO#read_bytes(Int32) because we skipped system/network
        # endianness check when writing the integer while read_bytes would;
        # we thus read it in the same as order as written
        buf = uninitialized StaticArray(UInt8, 4)
        reader_pipe.read_fully(buf.to_slice)
        raise_exception_from_errno(prepared_args[0], Errno.new(buf.unsafe_as(Int32)))
      else
        raise RuntimeError.new("BUG: Invalid error response received from subprocess")
      end
    ensure
      reader_pipe.close
    end

    pid
  end

  def self.prepare_args(command : String, args : Enumerable(String)?, shell : Bool) : {String, LibC::Char**}
    if shell
      command = %(#{command} "${@}") unless command.includes?(' ')
      argv_ary = ["/bin/sh", "-c", command, "sh"]

      if args
        unless command.includes?(%("${@}"))
          raise ArgumentError.new(%(Can't specify arguments in both command and args without including "${@}" into your command))
        end
      end

      pathname = "/bin/sh"
    else
      argv_ary = [command]
      pathname = command
    end

    argv_ary.concat(args) if args

    argv = argv_ary.map(&.check_no_null_byte.to_unsafe)
    {pathname, argv.to_unsafe}
  end

  # This method is similar to `.replace` (used for `Process.exec`) with some
  # differences because we're limited in what we can do in the pre-exec phase
  # between `fork` and `exec`.
  private def self.try_replace(prepared_args, envp, input, output, error, chdir)
    reopen_io(input, ORIGINAL_STDIN)
    reopen_io(output, ORIGINAL_STDOUT)
    reopen_io(error, ORIGINAL_STDERR)

    if chdir
      if 0 != LibC.chdir(chdir)
        return
      end
    end

    execvpe(*prepared_args, envp)
  end

  private def self.execvpe(file, argv, envp)
    {% if LibC.has_method?("execvpe") && !flag?("execvpe_impl") %}
      lock_write { LibC.execvpe(file, argv, envp) }
    {% else %}
      execvpe_impl(file, argv, envp)
    {% end %}
  end

  DEFAULT_PATH = "/usr/bin:/bin"

  # Darwin, DragonflyBSD, and FreeBSD < 14 don't have an `execvpe` function, so
  # we need to implement it ourselves.
  # This method runs between `fork` and `exec` and must be very cautious, such
  # as no memory allocations.
  private def self.execvpe_impl(file : String, argv : LibC::Char**, envp : LibC::Char**)
    if file.empty?
      Errno.value = Errno::ENOENT
      return
    end

    # When file contains a slash, it's already a pathname that we should execute.
    if file.includes?("/")
      lock_write { LibC.execve(file, argv, envp) }

      # Glibc implements a fallback if execve fails with ENOEXEC which tries
      # executing `file` with `/bin/sh`. This is a legacy compatibility feature and
      # has security concerns. We implement the behaviour of `execvpex`.
      return
    end

    path = if path_ptr = LibC.getenv("PATH")
             Slice.new(path_ptr, LibC.strlen(path_ptr))
           else
             DEFAULT_PATH.to_slice
           end

    if file.bytesize > LibC::NAME_MAX
      Errno.value = Errno::ENAMETOOLONG
      return
    end

    buffer = uninitialized UInt8[LibC::PATH_MAX]

    seen_eaccess = false

    while path.size > 0
      if index = path.index(':'.ord.to_u8!)
        path_entry = path[0, index]
        path += index

        # Do not advance a trailing `:` so that we read it as an empty path in
        # the next iteration
        path += 1 unless path.size == 1
      else
        path_entry = path
        path += path_entry.size
      end

      # When the full pathname would be too long, simply skip it.
      # This is an edge case. BSD implementations usually also print a warning.
      # Cosmopolitan libc even errors.
      if path_entry.size + file.bytesize + 2 >= buffer.size
        next
      end

      builder = buffer.to_slice

      if path_entry.empty?
        # empty path means current directory
        builder[0] = '.'.ord.to_u8!
        builder += 1
      else
        path_entry.copy_to(builder)
        builder += path_entry.size
      end
      builder[0] = '/'.ord.to_u8!
      builder += 1
      file.to_slice.copy_to(builder)
      builder += file.size
      builder[0] = 0

      lock_write { LibC.execve(buffer.to_slice[0, buffer.size - builder.size], argv, envp) }

      case Errno.value
      when Errno::EACCES
        # Non-terminal condition. Take note that we encountered EACCES and error
        # with that if no other candidate is found.
        seen_eaccess = true
      when Errno::ENOENT, Errno::ENOTDIR
        # Non terminal condition. Skip.
      else
        # Terminal condition. Return immediately. We found a file that exists
        # is accessible, but it wouldn't execute.
        return
      end
    end

    Errno.value = if seen_eaccess
                    # Erroring with ENOENT would be misleading if we found a candidate but
                    # couldn't access it and thus skipped it.
                    Errno::EACCES
                  else
                    # Make sure to set an error in case we never tried any path (e.g. `PATH=`)
                    Errno::ENOENT
                  end
  end

  def self.replace(command, args, shell, env, clear_env, input, output, error, chdir)
    prepared_args = prepare_args(command, args, shell)
    envp = Env.make_envp(env, clear_env)

    # The following steps are similar to `.try_replace` (used for `fork`/`exec`)
    # with some differences because we're not spawning a new process.
    reopen_io(input, ORIGINAL_STDIN)
    reopen_io(output, ORIGINAL_STDOUT)
    reopen_io(error, ORIGINAL_STDERR)

    if chdir
      ::Dir.cd(chdir) do
        execvpe(*prepared_args, envp)
      end
    else
      execvpe(*prepared_args, envp)
    end

    raise_exception_from_errno(command)
  end

  private def self.raise_exception_from_errno(command, errno = Errno.value)
    case errno
    when Errno::EACCES, Errno::ENOENT, Errno::ENOEXEC
      raise ::File::Error.from_os_error("Error executing process", errno, file: command)
    else
      raise IO::Error.from_os_error("Error executing process: '#{command}'", errno)
    end
  end

  private def self.reopen_io(src_io : IO::FileDescriptor, dst_io : IO::FileDescriptor)
    if src_io.closed?
      # Do not use FileDescriptor.file_descriptor_close here because it
      # mutates the memory of `dst_id.fd` in `close_volatile_fd?` which causes
      # problems with `vfork` behaviour.
      # We can ignore any errors from `LibC.close`.
      LibC.close(dst_io.fd)
    else
      src_io = to_real_fd(src_io)

      # dst_io.reopen(src_io)
      ret = LibC.dup2(src_io.fd, dst_io.fd)
      raise IO::Error.from_errno("dup2") if ret == -1

      FileDescriptor.set_blocking(dst_io.fd, true)
      dst_io.close_on_exec = false
    end
  end

  private def self.to_real_fd(fd : IO::FileDescriptor)
    case fd
    when STDIN  then ORIGINAL_STDIN
    when STDOUT then ORIGINAL_STDOUT
    when STDERR then ORIGINAL_STDERR
    else             fd
    end
  end

  def self.chroot(path)
    path.check_no_null_byte
    if LibC.chroot(path) != 0
      raise RuntimeError.from_errno("Failed to chroot")
    end

    if LibC.chdir("/") != 0
      errno = RuntimeError.from_errno("chdir after chroot failed")
      errno.callstack = Exception::CallStack.new
      errno.inspect_with_backtrace(STDERR)
      abort("Unresolvable state, exiting...")
    end
  end
end

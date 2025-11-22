require "c/signal"
require "c/unistd"

struct Crystal::System::Process
  def self.spawn(command, args, shell, env, clear_env, input, output, error, chdir)
    prepared_args = prepare_args(command, args, shell)

    r, w = FileDescriptor.system_pipe

    envp = Env.make_envp(env, clear_env)

    pid = self.fork_for_exec
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

  private def self.fork_for_exec
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

    pid = lock_write { LibC.fork }

    if 0 == pid
      # forked process

      Crystal::System::Signal.after_fork_before_exec

      # reset sigmask (inherited on exec)
      LibC.sigemptyset(pointerof(newmask))
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(newmask), nil)

      nil
    else
      # forking process

      errno = Errno.value
      LibC.pthread_sigmask(LibC::SIG_SETMASK, pointerof(oldmask), nil)

      if pid == -1
        raise RuntimeError.from_os_error("fork", errno)
      end

      pid
    end
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
end

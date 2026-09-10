require "c/signal"
require "c/unistd"

struct Crystal::System::Process
  private SPAWN_ERROR_EXCEPTION = 0_u8
  private SPAWN_ERROR_EXEC      = 1_u8
  private SPAWN_ERROR_CHDIR     = 2_u8

  def self.spawn(prepared_args, shell, env, clear_env, input, output, error, chdir, &)
    r, w = FileDescriptor.system_pipe

    envp = Env.make_envp(env, clear_env)

    pid = self.fork_for_exec
    if !pid
      LibC.close(r)
      begin
        self.try_replace(prepared_args, envp, input, output, error, chdir, w)
      rescue ex
        byte = SPAWN_ERROR_EXCEPTION
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
      case byte = reader_pipe.read_byte
      when nil
        # Pipe was closed, no error
      when SPAWN_ERROR_EXCEPTION
        # Error message coming
        message = reader_pipe.gets_to_end
        raise RuntimeError.new("Error executing process: '#{prepared_args[0]}': #{message}")
      when SPAWN_ERROR_EXEC, SPAWN_ERROR_CHDIR
        # Errno coming
        # can't use IO#read_bytes(Int32) because we skipped system/network
        # endianness check when writing the integer while read_bytes would;
        # we thus read it in the same as order as written
        buf = uninitialized StaticArray(UInt8, 4)
        reader_pipe.read_fully(buf.to_slice)
        errno = Errno.new(buf.unsafe_as(Int32))
        if byte == SPAWN_ERROR_CHDIR
          raise ::File::Error.from_os_error("Error while changing directory", errno, file: chdir.not_nil!)
        else
          raise_exception_from_errno(prepared_args[0], errno) do |errno, command|
            yield errno, command
          end
        end
      else
        raise RuntimeError.new("BUG: Invalid error response received from subprocess")
      end
    ensure
      reader_pipe.close
    end

    pid
  end

  private def self.fork_for_exec
    pid, errno = lock_write do
      pthread_disable_cancelstate do
        block_signals do |sigmask|
          pid = LibC.fork
          if pid == 0
            # forked process

            Crystal::System::Signal.after_fork_before_exec

            # reset sigmask (inherited on exec)
            LibC.sigemptyset(sigmask)
          end
          {pid, Errno.value}
        end
      end
    end

    case pid
    when 0
      # forked process
      nil
    when -1
      # forking process: error
      raise RuntimeError.from_os_error("fork", errno)
    else
      # forking process: success
      pid
    end
  end

  # This method is similar to `.replace` (used for `Process.exec`) with some
  # differences because we're limited in what we can do in the pre-exec phase
  # between `fork` and `exec`.
  private def self.try_replace(prepared_args, envp, input, output, error, chdir, error_fd)
    reopen_io(input, ORIGINAL_STDIN)
    reopen_io(output, ORIGINAL_STDOUT)
    reopen_io(error, ORIGINAL_STDERR)

    if chdir
      if 0 != LibC.chdir(chdir)
        write_spawn_error(error_fd, SPAWN_ERROR_CHDIR)
        return
      end
    end

    execvpe(*prepared_args, envp)
    write_spawn_error(error_fd, SPAWN_ERROR_EXEC)
  end

  private def self.write_spawn_error(fd, spawn_error : UInt8)
    errno = Errno.value.to_i32
    FileDescriptor.write_fully(fd, pointerof(spawn_error))
    FileDescriptor.write_fully(fd, pointerof(errno))
  end
end

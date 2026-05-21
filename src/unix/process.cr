require "../process"

module UNIX
  # Unix-specific process operations.
  #
  # Provides `fork` and `exec` as first-class, non-deprecated methods in a
  # namespace that makes their Unix-only nature explicit.
  #
  # ```
  # require "unix/process"
  # ```
  #
  # This class is automatically required on Unix when `"process"` is required.
  class Process < ::Process
    {% if flag?(:unix) %}
      # Duplicates the current process.
      #
      # Returns a `UNIX::Process` wrapping the child in the parent, and `nil`
      # inside the child. The event loop, signal handlers, and RNG are
      # reinitialized in the child automatically via
      # `Process.after_fork_child_callbacks`.
      #
      # NOTE: `Thread.stop_world` and `GC.lock_write` are intentionally absent.
      # `Thread.stop_world` can freeze workers mid-Boehm-allocator-lock; Boehm's
      # own `pthread_atfork` prepare handler then tries to acquire the same lock,
      # deadlocking inside `fork(2)`. `GC.lock_write` has the same issue because
      # `Crystal::Scheduler.resume` holds `GC.lock_read` across `swapcontext`.
      # Boehm handles its own allocator state via `LibGC.set_handle_fork(1)`;
      # under `-Dpreview_mt`, call `Crystal::Scheduler.reinit_child` in the child
      # to reset Crystal's own GC RWLock and scheduler state.
      #
      # ```
      # if child = UNIX::Process.fork
      #   child.wait  # parent
      # else
      #   # child work here — runtime already reinitialized
      # end
      # ```
      def self.fork : UNIX::Process?
        pid, errno = ::Process.quiesce { r = LibC.fork; {r, Errno.value} }

        case pid
        when 0
          {% if flag?(:preview_mt) %}
            Crystal::Scheduler.reinit_child
          {% end %}
          ::Process.after_fork_child_callbacks.each(&.call)
          nil
        when -1
          raise RuntimeError.from_os_error("fork", errno)
        else
          new Crystal::System::Process.new(pid)
        end
      end

      # Runs the given block in a new child process and returns a
      # `UNIX::Process` representing it. The child calls `LibC._exit` when the
      # block returns or raises, so at-exit handlers and finalizers do not run.
      #
      # ```
      # child = UNIX::Process.fork do
      #   puts "I am the child (pid #{Process.pid})"
      # end
      # child.wait
      # ```
      def self.fork(&) : UNIX::Process
        if child = fork
          return child
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

      # Returns the process group identifier of the current process.
      def self.pgid : Int64
        Crystal::System::Process.pgid.to_i64
      end

      # Returns the process group identifier of the process identified by *pid*.
      def self.pgid(pid : Int) : Int64
        Crystal::System::Process.pgid(pid).to_i64
      end

      # Sends *signal* to the process identified by *pid*.
      def self.signal(signal : Signal, pid : Int) : Nil
        Crystal::System::Process.signal(pid, signal.value)
      end

      # Changes the root directory and the current working directory for the
      # current process.
      #
      # Security: `chroot` on its own is not an effective means of mitigation.
      # At minimum the process needs to also drop privileges as soon as feasible
      # after the `chroot`. Changes to the directory hierarchy or file descriptors
      # passed via `recvmsg(2)` from outside the `chroot` jail may allow a
      # restricted process to escape, even if it is unprivileged.
      #
      # ```
      # UNIX::Process.chroot("/var/empty")
      # ```
      def self.chroot(path : String) : Nil
        Crystal::System::Process.chroot(path)
      end

      # Sends *signal* to this process.
      def signal(signal : Signal) : Nil
        Crystal::System::Process.signal(@process_info.pid, signal.value)
      end
    {% end %}

    # Replaces the current process with a new one. This function never returns.
    #
    # *command* is the name or path of the executable to replace the current
    # process with. If *shell* is `true`, the command string is passed to the
    # system shell (`/bin/sh -c`) instead.
    #
    # *args* are the arguments passed to the new process. If *shell* is `true`
    # and *args* is given, the args are appended after a `--` separator.
    #
    # *env* provides additional or overriding environment variables. If
    # *clear_env* is `true`, only the variables in *env* are set; otherwise the
    # child inherits the parent's environment with *env* merged in.
    #
    # *input*, *output*, *error* configure the standard streams of the new
    # process. Each accepts a `Process::Redirect` value or an
    # `IO::FileDescriptor`. `Redirect::Pipe` is not valid here.
    #
    # *chdir* changes the working directory before exec.
    #
    # Raises `IO::Error` if executing the command fails (for example if the
    # executable doesn't exist).
    #
    # ```
    # UNIX::Process.exec("echo", ["hello"])
    # ```
    def self.exec(command : String, args : Enumerable(String)? = nil, env : ::Process::Env = nil, clear_env : Bool = false, shell : Bool = false,
                  input : ::Process::ExecStdio = ::Process::Redirect::Inherit, output : ::Process::ExecStdio = ::Process::Redirect::Inherit,
                  error : ::Process::ExecStdio = ::Process::Redirect::Inherit, chdir : Path | String? = nil) : NoReturn
      input_fd  = exec_stdio_to_fd(input,  for: STDIN)
      output_fd = exec_stdio_to_fd(output, for: STDOUT)
      error_fd  = exec_stdio_to_fd(error,  for: STDERR)
      Crystal::System::Process.replace(command, args, shell, env, clear_env, input_fd, output_fd, error_fd, chdir)
    end
  end
end

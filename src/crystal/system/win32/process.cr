require "c/processthreadsapi"
require "c/handleapi"
require "c/synchapi"
require "process/shell"
require "crystal/atomic_semaphore"

struct Crystal::System::Process
  getter pid : LibC::DWORD
  @thread_id : LibC::DWORD
  @process_handle : LibC::HANDLE

  @@interrupt_handler : Proc(Nil)?
  @@interrupt_count = Crystal::AtomicSemaphore.new
  @@win32_interrupt_handler : LibC::PHANDLER_ROUTINE?
  @@setup_interrupt_handler = Atomic::Flag.new

  def initialize(process_info)
    @pid = process_info.dwProcessId
    @thread_id = process_info.dwThreadId
    @process_handle = process_info.hProcess
  end

  def release
    return if @process_handle == LibC::HANDLE.null
    close_handle(@process_handle)
    @process_handle = LibC::HANDLE.null
  end

  def wait
    if LibC.WaitForSingleObject(@process_handle, LibC::INFINITE) != LibC::WAIT_OBJECT_0
      raise RuntimeError.from_winerror("WaitForSingleObject")
    end

    # WaitForSingleObject returns immediately once ExitProcess is called in the child, but
    # the process still has yet to be destructed by the OS and have it's memory unmapped.
    # Since the semantics on unix are that the resources of a process have been released once
    # waitpid returns, we wait 5 milliseconds to attempt to replicate this behaviour.
    sleep 5.milliseconds

    if LibC.GetExitCodeProcess(@process_handle, out exit_code) == 0
      raise RuntimeError.from_winerror("GetExitCodeProcess")
    end
    if exit_code == LibC::STILL_ACTIVE
      raise "BUG: process still active"
    end
    exit_code
  end

  def exists?
    Crystal::System::Process.exists?(@pid)
  end

  def terminate
    raise NotImplementedError.new("Process.kill")
  end

  def self.exit(status)
    LibC.exit(status)
  end

  def self.pid
    LibC.GetCurrentProcessId
  end

  def self.pgid
    raise NotImplementedError.new("Process.pgid")
  end

  def self.pgid(pid)
    raise NotImplementedError.new("Process.pgid")
  end

  def self.ppid
    raise NotImplementedError.new("Process.ppid")
  end

  def self.signal(pid, signal)
    raise NotImplementedError.new("Process.signal")
  end

  def self.on_interrupt(&@@interrupt_handler : ->) : Nil
    restore_interrupts!
    @@win32_interrupt_handler = handler = LibC::PHANDLER_ROUTINE.new do |event_type|
      next 0 unless event_type.in?(LibC::CTRL_C_EVENT, LibC::CTRL_BREAK_EVENT)
      @@interrupt_count.signal
      1
    end
    LibC.SetConsoleCtrlHandler(handler, 1)
  end

  def self.ignore_interrupts! : Nil
    remove_interrupt_handler
    LibC.SetConsoleCtrlHandler(nil, 1)
  end

  def self.restore_interrupts! : Nil
    remove_interrupt_handler
    LibC.SetConsoleCtrlHandler(nil, 0)
  end

  private def self.remove_interrupt_handler
    if old = @@win32_interrupt_handler
      LibC.SetConsoleCtrlHandler(old, 0)
      @@win32_interrupt_handler = nil
    end
  end

  def self.start_interrupt_loop : Nil
    return unless @@setup_interrupt_handler.test_and_set

    spawn(name: "Interrupt signal loop") do
      while true
        @@interrupt_count.wait { sleep 50.milliseconds }

        if handler = @@interrupt_handler
          non_nil_handler = handler # if handler is closured it will also have the Nil type
          spawn do
            non_nil_handler.call
          rescue ex
            ex.inspect_with_backtrace(STDERR)
            STDERR.puts("FATAL: uncaught exception while processing interrupt handler, exiting")
            STDERR.flush
            LibC._exit(1)
          end
        end
      end
    end
  end

  def self.exists?(pid)
    handle = LibC.OpenProcess(LibC::PROCESS_QUERY_INFORMATION, 0, pid)
    return false if handle.nil?
    begin
      if LibC.GetExitCodeProcess(handle, out exit_code) == 0
        raise RuntimeError.from_winerror("GetExitCodeProcess")
      end
      exit_code == LibC::STILL_ACTIVE
    ensure
      close_handle(handle)
    end
  end

  def self.times
    if LibC.GetProcessTimes(LibC.GetCurrentProcess, out create, out exit, out kernel, out user) == 0
      raise RuntimeError.from_winerror("GetProcessTimes")
    end
    ::Process::Tms.new(
      Crystal::System::Time.filetime_to_f64secs(user),
      Crystal::System::Time.filetime_to_f64secs(kernel),
      0,
      0)
  end

  def self.fork
    raise NotImplementedError.new("Process.fork")
  end

  def self.fork(&)
    raise NotImplementedError.new("Process.fork")
  end

  private def self.handle_from_io(io : IO::FileDescriptor, parent_io)
    ret = LibC._get_osfhandle(io.fd)
    raise RuntimeError.from_winerror("_get_osfhandle") if ret == -1
    source_handle = LibC::HANDLE.new(ret)

    cur_proc = LibC.GetCurrentProcess
    if LibC.DuplicateHandle(cur_proc, source_handle, cur_proc, out new_handle, 0, true, LibC::DUPLICATE_SAME_ACCESS) == 0
      raise RuntimeError.from_winerror("DuplicateHandle")
    end

    new_handle
  end

  def self.spawn(command_args, env, clear_env, input, output, error, chdir)
    startup_info = LibC::STARTUPINFOW.new
    startup_info.cb = sizeof(LibC::STARTUPINFOW)
    startup_info.dwFlags = LibC::STARTF_USESTDHANDLES

    startup_info.hStdInput = handle_from_io(input, STDIN)
    startup_info.hStdOutput = handle_from_io(output, STDOUT)
    startup_info.hStdError = handle_from_io(error, STDERR)

    process_info = LibC::PROCESS_INFORMATION.new

    if LibC.CreateProcessW(
         nil, System.to_wstr(command_args), nil, nil, true, LibC::CREATE_UNICODE_ENVIRONMENT,
         make_env_block(env, clear_env), chdir.try { |str| System.to_wstr(str) },
         pointerof(startup_info), pointerof(process_info)
       ) == 0
      error = WinError.value
      case error.to_errno
      when Errno::EACCES, Errno::ENOENT
        raise ::File::Error.from_os_error("Error executing process", error, file: command_args)
      else
        raise IO::Error.from_os_error("Error executing process: '#{command_args}'", error)
      end
    end

    close_handle(process_info.hThread)

    close_handle(startup_info.hStdInput)
    close_handle(startup_info.hStdOutput)
    close_handle(startup_info.hStdError)

    process_info
  end

  def self.prepare_args(command : String, args : Enumerable(String)?, shell : Bool) : String
    if shell
      if args
        raise NotImplementedError.new("Process with args and shell: true is not supported on Windows")
      end
      command
    else
      command_args = [command]
      command_args.concat(args) if args
      ::Process.quote_windows(command_args)
    end
  end

  def self.replace(command_args, env, clear_env, input, output, error, chdir) : NoReturn
    raise NotImplementedError.new("Process.exec")
  end

  def self.chroot(path)
    raise NotImplementedError.new("Process.chroot")
  end

  protected def self.make_env_block(env, clear_env : Bool) : UInt16*
    # If neither clearing nor adding anything, use the default behavior of inheriting everything.
    return Pointer(UInt16).null if !env && !clear_env

    # Emulate case-insensitive behavior using a Hash like {"KEY" => {"kEy", "value"}, ...}
    final_env = {} of String => {String, String}
    unless clear_env
      Crystal::System::Env.each do |key, val|
        final_env[key.upcase] = {key, val}
      end
    end
    env.try &.each do |(key, val)|
      if val
        # Note: in the case of overriding, the last "case-spelling" of the key wins.
        final_env[key.upcase] = {key, val}
      else
        final_env.delete key.upcase
      end
    end
    # The "values" we're passing are actually key-value pairs.
    Crystal::System::Env.make_env_block(final_env.each_value)
  end
end

private def close_handle(handle)
  if LibC.CloseHandle(handle) == 0
    raise RuntimeError.from_winerror("CloseHandle")
  end
end

require "c/processthreadsapi"
require "c/winuser"
require "c/tlhelp32"

POWERSHELL = "powershell.exe"
CMD        = "cmd.exe"

class Process
  @@mutex = Mutex.new

  @@pending = {} of Int64 => LibC::DWORD
  @@waiting = {} of Int64 => Channel(Int32)

  @handle : LibC::HANDLE? = nil
  @pi = LibC::PROCESS_INFORMATION.new
  @child_descriptors = Array(IO::FileDescriptor).new

  protected def self.exit_system(status = 0) : NoReturn
    LibC.ExitProcess(status)
  end

  protected def self.pid_system : Int64
    LibC.GetCurrentProcessId.to_i64
  end

  protected def self.ppid_system : Int64
    pid = LibC.GetCurrentProcessId
    snapshot = LibC.CreateToolhelp32Snapshot(LibC::TH32CS_SNAPPROCESS, 0)
    begin
      if (snapshot == LibC::INVALID_HANDLE_VALUE)
        raise WinError.new("CreateToolhelp32Snapshot")
      end

      pe32 = LibC::PROCESSENTRY32.new
      pe32.dwSize = sizeof(LibC::PROCESSENTRY32)
      if (LibC.Process32First(snapshot, pointerof(pe32)) == LibC::FALSE)
        raise WinError.new("Process32First")
      end

      loop do
        if (pe32.th32ProcessID == pid)
          return pe32.th32ParentProcessID.to_i64
        end
        break if LibC.Process32Next(snapshot, pointerof(pe32)) == LibC::FALSE
      end
    ensure
      if (snapshot != LibC::INVALID_HANDLE_VALUE)
        LibC.CloseHandle(snapshot)
      end
    end
    -1_i64
  end

  def self.current_process_handle : LibC::HANDLE
    LibC.GetCurrentProcess
  end

  def self.current_thread_handle : LibC::HANDLE
    LibC.GetCurrentThread
  end

  protected def self.exists_system(pid : Int64)
    handle = LibC.OpenProcess(LibC::PROCESS_QUERY_INFORMATION, LibC::FALSE, pid.to_u32)
    if handle == LibC::NULL
      return false
    else
      LibC.CloseHandle(handle)
      return true
    end
  end

  protected def create_and_exec(command : String, args : (Array | Tuple)?, env : Env?, clear_env : Bool, fork_input : IO::FileDescriptor, fork_output : IO::FileDescriptor, fork_error : IO::FileDescriptor, chdir : String?, reader_pipe, writer_pipe)
    # like in child process
    self.exec_internal(command, args, env, clear_env, fork_input, fork_output, fork_error, chdir)
  rescue ex : Errno
    writer_pipe.write_bytes(ex.errno)
    writer_pipe.write_bytes(ex.message.try(&.bytesize) || 0)
    writer_pipe << ex.message
    0_i64
  rescue ex
    ex.inspect_with_backtrace STDERR
    STDERR.flush
    0_i64
  end

  def self.duplicate_handle(fd, inheritable)
    ret = LibC._dup(fd.fd)
    if ret == -1
      raise Errno.new("Could not duplicate file descriptor")
    end
    IO::FileDescriptor.new(ret)
  end

  def exec_internal(command : String, args : (Array | Tuple)?, env : Env?, clear_env : Bool, input : IO::FileDescriptor, output : IO::FileDescriptor, error : IO::FileDescriptor, chdir : String?)
    startupinfo = LibC::STARTUPINFOW.new
    # only listed handlers are inherited
    inherited_handle_list = Array(LibC::HANDLE).new

    if fd = Process.duplicate_handle(input, true)
      @child_descriptors << fd
      handle = fd.windows_handle
      startupinfo.hStdInput = handle
      inherited_handle_list << handle
    end

    if fd = Process.duplicate_handle(output, true)
      @child_descriptors << fd
      handle = fd.windows_handle
      startupinfo.hStdOutput = handle
      inherited_handle_list << handle
    end

    if fd = Process.duplicate_handle(error, true)
      @child_descriptors << fd
      handle = fd.windows_handle
      startupinfo.hStdError = handle
      inherited_handle_list << handle
    end

    startupinfo.dwFlags = LibC::STARTF_USESTDHANDLES

    LibC.InitializeProcThreadAttributeList(LibC::NULL, 1_u32, 0, out lpSize)
    attribute_list = Pointer(Void).malloc(lpSize.to_u64)
    if LibC.InitializeProcThreadAttributeList(attribute_list, 1_u32, 0, pointerof(lpSize)) == LibC::FALSE
      raise WinError.new("InitializeProcThreadAttributeList")
    end

    if inherited_handle_list.size > 0
      if LibC.UpdateProcThreadAttribute(attribute_list, 0, LibC::PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
           inherited_handle_list, sizeof(LibC::HANDLE) * inherited_handle_list.size, nil, nil) == LibC::FALSE
        raise WinError.new("UpdateProcThreadAttribute")
      end
    end

    startupinfoex = LibC::STARTUPINFOEXW.new
    startupinfoex.startupInfo = startupinfo
    startupinfoex.lpAttributeList = attribute_list
    startupinfoex.startupInfo.cb = sizeof(LibC::STARTUPINFOEXW)

    args = args.nil? ? "" : "#{args.join(' ')}"
    command_line = %("#{command}" #{args})
    ret = LibC.CreateProcessW(
      nil,                                                                   # module name
      to_windows_path(command_line),                                         # command line args
      nil,                                                                   # Process handle not inheritable
      nil,                                                                   # Thread handle not inheritable
      LibC::TRUE,                                                            # Set handle inheritance to TRUE
      LibC::CREATE_UNICODE_ENVIRONMENT | LibC::EXTENDED_STARTUPINFO_PRESENT, # Use UTF-16 ENV Block
      Process.create_env_block(env, clear_env),
      chdir ? to_windows_path(chdir) : nil, # Use chdir or parent's starting directory
      pointerof(startupinfoex),             # Pointer to STARTUPINFOEX structure
      pointerof(@pi)    )                   # Pointer to PROCESS_INFORMATION structure
    if ret != 0
      wait_install_res = LibC.RegisterWaitForSingleObject(out wait_handle, @pi.hProcess, ->Process.on_exited(Void*, Bool), Box.box(self), LibC::INFINITE, LibC::WT_EXECUTEONLYONCE)
      if (wait_install_res == LibC::FALSE)
        raise WinError.new("RegisterWaitForSingleObject")
      end
      @handle = wait_handle
      @pi.dwProcessId.to_i64
    else
      raise WinError.new("CreateProcessW")
    end
  end

  protected def self.on_exited(context : Void*, is_time_out : Bool)
    process = Box(::Process).unbox(context)
    process.on_exited
  end

  protected def on_exited
    @child_descriptors.each do |fd|
      LibC._close(fd.fd) # ignore fail when already closed by child process
    end
    if LibC.GetExitCodeProcess(@pi.hProcess, out exit_code) == LibC::FALSE
      raise WinError.new("GetExitCodeProcess")
    end
    # Close process and thread handles.
    LibC.CloseHandle(@pi.hProcess)
    LibC.CloseHandle(@pi.hThread)
    @@mutex.lock
    if channel = @@waiting.delete(@pid)
      @@mutex.unlock
      channel.send(exit_code.to_i32)
      channel.close
    else
      @@pending[@pid] = exit_code
      @@mutex.unlock
    end
  end

  protected def close_system
    if @handle
      LibC.UnregisterWait(@handle)
    end
  end

  private def self.shell
    return ENV["comspec"]? || CMD
  end

  protected def self.system_prepare_shell(command, args)
    shell = self.shell

    if shell.ends_with?(POWERSHELL)
      shell_args = ["-NoProfile", "-NonInteractive", "-NoLogo", "-Command", command]
    elsif shell.ends_with?(CMD)
      shell_args = ["/C", command]
    else
      raise "Unsupported shell #{shell}"
    end

    if args
      shell_args.concat(args)
    end

    command = shell
    args = shell_args
    {command, args}
  end

  # This function is used internally by :func:`CreateProcess` to convert
  # the input to ``lpEnvironment`` to a string which the underlying C API
  # call will understand.
  #
  # An environment block consists of a null-terminated block of null-terminated strings. Each string is in the following form:
  # name=value\0
  #
  # Because the equal sign is used as a separator, it must not be used in the name of an environment variable.
  #
  # An environment block can contain Unicode characters because we includes CREATE_UNICODE_ENVIRONMENT flag in dwCreationFlags
  # A Unicode environment block is terminated by four zero bytes: two for the last string, two more to terminate the block.
  protected def self.create_env_block(env : Env?, clear_env : Bool)
    final_env : Env = {} of String => String
    if LibC.CreateEnvironmentBlock(out pointer, nil, LibC::FALSE) == LibC::FALSE
      raise WinError.new("CreateEnvironmentBlock")
    end
    env_block = pointer.as(Pointer(UInt16))
    begin
      Crystal::System::Env.parse_env_block(env_block) do |key, val|
        final_env[key] = val
      end
    ensure
      LibC.DestroyEnvironmentBlock(pointer)
    end
    if !clear_env
      ENV.each do |key, val|
        final_env[key] = val
      end
    end
    env.try &.each do |key, val|
      final_env[key] = val
    end
    builder = WinEnvBuilder.new
    final_env.each do |key, val|
      add_to_env_block(builder, key, val)
    end
    # terminate the block
    builder.write(0_u16)
    builder.buffer
  end

  private def self.add_to_env_block(block : WinEnvBuilder, key : String, val : String)
    # From Microsoft's documentation on `lpEnvironment`:
    # Because the equal sign is used as a separator, it must not be used
    # in the name of an environment variable.
    if !key.includes?('=') && !key.empty?
      block.write(key, val)
    end
  end

  protected def self.wait_system(pid : Int64) : Channel(Int32)
    channel = Channel(Int32).new(1)
    @@mutex.lock
    if exit_code = @@pending.delete(pid)
      @@mutex.unlock
      channel.send(exit_code.to_i32)
      channel.close
    else
      @@waiting[pid] = channel
      @@mutex.unlock
    end

    channel
  end

  protected def terminate_system
    hwnd = find_main_window(@pi.dwProcessId)
    if hwnd.address != 0
      LibC.PostMessageW(hwnd, LibC::WM_CLOSE, 0, 0)
    else
      LibC.PostThreadMessageW(@pi.dwThreadId, LibC::WM_QUIT, 0, 0)
    end
  end

  protected def kill_system
    LibC.TerminateProcess(@pi.hProcess, -1)
  end

  struct FindMainWindowParam
    property process_id : LibC::DWORD = 0
    property window_handle : LibC::HANDLE = LibC::HANDLE.null
  end

  protected def find_main_window(process_id : LibC::DWORD) : LibC::HWND
    data = FindMainWindowParam.new
    data.process_id = process_id
    LibC.EnumWindows(->Process.enum_windows_callback(LibC::HWND, LibC::LPARAM), Box.box(data).address)
    data.window_handle
  end

  protected def self.enum_windows_callback(handle : LibC::HWND, lparam : LibC::LPARAM) : LibC::BOOL
    data = Box(FindMainWindowParam).unbox(Pointer(Void).new(lparam))
    process_id = LibC::DWORD.new(0)
    LibC.GetWindowThreadProcessId(handle, pointerof(process_id))
    if data.process_id != process_id || !is_main_window(handle)
      return 1
    else
      data.window_handle = handle
      return 0
    end
  end

  protected def self.is_main_window(handle : LibC::HWND) : Bool
    LibC.GetWindow(handle, LibC::GW_OWNER).address == 0 && LibC.IsWindowVisible(handle) == 1
  end

  def self.run_ps(powershell_script : String, env : Env = nil, clear_env : Bool = false,
                  input : Stdio = Redirect::Close, output : Stdio = Redirect::Pipe, error : Stdio = Redirect::Inherit, chdir : String? = nil, &block : Process ->)
    args = ["-NoProfile", "-NonInteractive", "-NoLogo"]
    if input == Redirect::Close
      args << "-Command"
      args << "-"
    else
      slice_16 = powershell_script.to_utf16
      pointer = slice_16.to_unsafe
      bytes = Slice(UInt8).new(pointer.as(Pointer(UInt8)), slice_16.size*2)
      encoded = Base64.strict_encode(bytes)
      args << "-encodedCommand"
      args << encoded
    end
    passed_input = (input == Redirect::Close ? Redirect::Pipe : input)
    process = new("powershell.exe", args, env, clear_env, false, passed_input, output, error, chdir)
    if input == Redirect::Close
      process.input << powershell_script
      process.input << "\r\n"
      process.input.close
    end
    begin
      value = yield process
      $? = process.wait
      value
    rescue ex
      process.terminate
      raise ex
    end
  end

  def self.run_ps(powershell_script : String, env : Env = nil, clear_env : Bool = false, chdir : String? = nil) : String
    Process.run_ps(powershell_script, env: env, clear_env: clear_env, chdir: chdir) do |proc|
      proc.output.gets_to_end
    end
  end

  private def to_windows_path(path : String) : LibC::LPWSTR
    path.check_no_null_byte.to_utf16.to_unsafe
  end

  private class WinEnvBuilder
    getter wchar_size : Int32
    getter capacity : Int32
    getter buffer : Pointer(UInt16)

    def initialize(capacity : Int = 1)
      @buffer = GC.malloc_atomic(capacity.to_u32*2).as(UInt16*)
      @capacity = capacity.to_i
      @wchar_size = 0
    end

    def slice
      Slice.new(buffer, wchar_size)
    end

    def bytes
      Slice.new(buffer.as(Pointer(UInt8)), wchar_size*2)
    end

    def write(key : String, val : String)
      key_val_pair = "#{key}=#{val}"
      write(key_val_pair.check_no_null_byte.to_utf16)
      write(0_u16)
    end

    private def write(slice : Slice(UInt16)) : Nil
      return if slice.empty?

      count = slice.size
      new_size = @wchar_size + count
      if new_size > @capacity
        resize_to_capacity(Math.pw2ceil(new_size))
      end

      slice.copy_to(@buffer + @wchar_size, count)
      @wchar_size += count

      nil
    end

    def write(wchar : UInt16)
      new_size = @wchar_size + 1
      if new_size > @capacity
        resize_to_capacity(Math.pw2ceil(new_size))
      end

      @buffer[@wchar_size] = wchar
      @wchar_size += 1

      nil
    end

    private def resize_to_capacity(capacity)
      @capacity = capacity
      @buffer = @buffer.realloc(@capacity*2)
    end
  end
end

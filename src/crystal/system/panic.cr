module Crystal::System
  # Prints a system error message on the standard error then exits with an error
  # status.
  #
  # You should always prefer raising an exception, built with
  # `RuntimeError.from_os_error` for example, but there are a few cases where we
  # can't allocate any memory (e.g. stop the world) and still need to fail when
  # reaching a system error.
  def self.panic(syscall_name : String, error : Errno | WinError | WasiError) : NoReturn
    System.print_error("%s failed with ", syscall_name)
    error.unsafe_message { |slice| System.print_error(slice) }
    System.print_error(" (%s)\n", error.to_s)

    LibC._exit(1)
  end
end

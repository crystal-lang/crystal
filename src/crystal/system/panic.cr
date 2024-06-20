module Crystal::System
  # Prints a system error message on the standard error then exits with an error
  # status.
  #
  # You should always prefer raising an exception, built with
  # `RuntimeError.from_os_error` for example, but there are a few cases where we
  # can't allocate any memory (e.g. stop the world) and still need to fail when
  # reaching a system error.
  #
  # On Linux *error* defaults to the current `Errno`. On Windows it defaults to
  # the current `WinError`. On Wasm32 the actual `WasiError` must be passed.
  {% if flag?(:unix) %}
    def self.panic(syscall_name : String, error : Errno = Errno.value) : NoReturn
      buffer = LibC.strerror(error.value)
      message = Bytes.new(buffer, LibC.strlen(buffer))
      System.print_error("%s failed with ", syscall_name)
      System.print_error(message)
      System.print_error(" (%s)\n", error.to_s)
      exit 1
    end
  {% elsif flag?(:win32) %}
    def self.panic(syscall_name : String, error : WinError = WinError.value) : NoReturn
      buffer = uninitialized UInt16[256]
      size = LibC.FormatMessageW(LibC::FORMAT_MESSAGE_FROM_SYSTEM, nil, error.value, 0, buffer, buffer.size, nil)
      message = buffer.to_slice[0, size]
      System.print_error("%s failed with ", syscall_name)
      System.print_error(message)
      System.print_error(" (%s)\n", error.to_s)
      exit 1
    end
  {% elsif flag?(:wasm32) %}
    def self.panic(syscall_name : String, error : WasiError) : NoReturn
      System.print_error("%s failed with %s (%s)", syscall_name, error.message, error.to_s)
      exit 1
    end
  {% else %}
    {% raise "Unsupported target" %}
  {% end %}
end

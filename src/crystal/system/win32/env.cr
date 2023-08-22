require "crystal/system/windows"
require "c/winbase"
require "c/processenv"

module Crystal::System::Env
  # Sets an environment variable or unsets it if *value* is `nil`.
  def self.set(key : String, value : String) : Nil
    check_valid_key(key)
    key = System.to_wstr(key, "key")
    value = System.to_wstr(value, "value")

    if LibC.SetEnvironmentVariableW(key, value) == 0
      raise RuntimeError.from_winerror("SetEnvironmentVariableW")
    end
  end

  # Unsets an environment variable.
  def self.set(key : String, value : Nil) : Nil
    check_valid_key(key)
    key = System.to_wstr(key, "key")

    if LibC.SetEnvironmentVariableW(key, nil) == 0
      raise RuntimeError.from_winerror("SetEnvironmentVariableW")
    end
  end

  # Gets an environment variable.
  def self.get(key : String) : String?
    return nil unless valid_key?(key)
    key = System.to_wstr(key, "key")

    System.retry_wstr_buffer do |buffer, small_buf|
      # `GetEnvironmentVariableW` doesn't set last error on success but we need
      # a success message in order to identify if length == 0 means not found or
      # the value is an empty string.
      LibC.SetLastError(WinError::ERROR_SUCCESS)
      length = LibC.GetEnvironmentVariableW(key, buffer, buffer.size)

      if 0 < length < buffer.size
        return String.from_utf16(buffer[0, length])
      elsif small_buf && length > 0
        next length
      else
        case last_error = WinError.value
        when WinError::ERROR_SUCCESS
          return ""
        when WinError::ERROR_ENVVAR_NOT_FOUND
          return
        else
          raise RuntimeError.from_os_error("GetEnvironmentVariableW", last_error)
        end
      end
    end
  end

  # Returns `true` if environment variable is set.
  def self.has_key?(key : String) : Bool
    return false unless valid_key?(key)
    key = System.to_wstr(key, "key")

    buffer = uninitialized UInt16[1]
    LibC.GetEnvironmentVariableW(key, buffer, buffer.size) != 0
  end

  # Iterates all environment variables.
  def self.each(&block : String, String ->)
    orig_pointer = pointer = LibC.GetEnvironmentStringsW
    raise RuntimeError.from_winerror("GetEnvironmentStringsW") if pointer.null?

    begin
      while !pointer.value.zero?
        string, pointer = String.from_utf16(pointer)
        # Skip internal environment variables that are reserved by `cmd.exe`
        # (`%=ExitCode%`, `%=ExitCodeAscii%`, `%=::%`, `%=C:%` ...)
        next if string.starts_with?('=')
        key, _, value = string.partition('=')
        yield key, value
      end
    ensure
      LibC.FreeEnvironmentStringsW(orig_pointer)
    end
  end

  # Used internally to create an input for `CreateProcess` `lpEnvironment`.
  def self.make_env_block(env : Enumerable({String, String}))
    # NOTE: the entire string contains embedded null bytes so we can't use
    # `System.to_wstr` here
    String.build do |io|
      env.each do |(key, value)|
        check_valid_key(key)
        io << key.check_no_null_byte("key") << '=' << value.check_no_null_byte("value") << '\0'
      end
      io << '\0'
    end.to_utf16.to_unsafe
  end

  private def self.valid_key?(key : String)
    !(key.empty? || key.includes?('='))
  end

  private def self.check_valid_key(key : String)
    raise ArgumentError.new("Invalid env key #{key.inspect}") unless valid_key?(key)
  end
end

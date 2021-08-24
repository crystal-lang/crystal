require "crystal/system/windows"
require "c/winbase"
require "c/processenv"

module Crystal::System::Env
  # Sets an environment variable or unsets it if *value* is `nil`.
  def self.set(key : String, value : String) : Nil
    key.check_no_null_byte("key")
    value.check_no_null_byte("value")

    if LibC.SetEnvironmentVariableW(key.to_utf16, value.to_utf16) == 0
      raise RuntimeError.from_winerror("SetEnvironmentVariableW")
    end
  end

  # Unsets an environment variable.
  def self.set(key : String, value : Nil) : Nil
    key.check_no_null_byte("key")

    if LibC.SetEnvironmentVariableW(key.to_utf16, nil) == 0
      raise RuntimeError.from_winerror("SetEnvironmentVariableW")
    end
  end

  # Gets an environment variable.
  def self.get(key : String) : String?
    key.check_no_null_byte("key")

    System.retry_wstr_buffer do |buffer, small_buf|
      # `GetEnvironmentVariableW` doesn't set last error on success but we need
      # a success message in order to identify if length == 0 means not found or
      # the value is an empty string.
      LibC.SetLastError(WinError::ERROR_SUCCESS)
      length = LibC.GetEnvironmentVariableW(key.to_utf16, buffer, buffer.size)

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
    key.check_no_null_byte("key")

    buffer = uninitialized UInt16[1]
    LibC.GetEnvironmentVariableW(key.to_utf16, buffer, buffer.size) != 0
  end

  # Iterates all environment variables.
  def self.each(&block : String, String ->)
    orig_pointer = pointer = LibC.GetEnvironmentStringsW
    raise RuntimeError.from_winerror("GetEnvironmentStringsW") if pointer.null?

    begin
      while !pointer.value.zero?
        string, pointer = String.from_utf16(pointer)
        key, _, value = string.partition('=')
        # The actual env variables are preceded by these weird lines in the output:
        # "=::=::\", "=C:=c:\foo\bar", "=ExitCode=00000000" -- skip them.
        next if key.empty?
        yield key, value
      end
    ensure
      LibC.FreeEnvironmentStringsW(orig_pointer)
    end
  end

  # Used internally to create an input for `CreateProcess` `lpEnvironment`.
  def self.make_env_block(env : Enumerable({String, String}))
    String.build do |io|
      env.each do |(key, value)|
        if key.includes?('=') || key.empty?
          raise ArgumentError.new("Invalid env key #{key.inspect}")
        end
        io << key.check_no_null_byte("key") << '=' << value.check_no_null_byte("value") << '\0'
      end
      io << '\0'
    end.to_utf16.to_unsafe
  end
end

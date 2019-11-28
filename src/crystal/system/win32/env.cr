require "crystal/system/windows"
require "c/winbase"

module Crystal::System::Env
  # Sets an environment variable or unsets it if *value* is `nil`.
  def self.set(key : String, value : String) : Nil
    key.check_no_null_byte("key")
    value.check_no_null_byte("value")

    if LibC.SetEnvironmentVariableW(key.to_utf16, value.to_utf16) == 0
      raise WinError.new("SetEnvironmentVariableW")
    end
  end

  # Unsets an environment variable.
  def self.set(key : String, value : Nil) : Nil
    key.check_no_null_byte("key")

    if LibC.SetEnvironmentVariableW(key.to_utf16, nil) == 0
      raise WinError.new("SetEnvironmentVariableW")
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
        case last_error = LibC.GetLastError
        when WinError::ERROR_SUCCESS
          return ""
        when WinError::ERROR_ENVVAR_NOT_FOUND
          return
        else
          raise WinError.new("GetEnvironmentVariableW", last_error)
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
    pointer = LibC.GetEnvironmentStringsW
    raise WinError.new("GetEnvironmentStringsW") if pointer.null?
    begin
      self.parse_env_block(pointer) { |key, val| yield key, val }
    ensure
      LibC.FreeEnvironmentStringsW(pointer)
    end
  end

  def self.parse_env_block(pointer : Pointer(UInt16), &block : String, String ->)
    while !pointer.value.zero?
      string, pointer = String.from_utf16(pointer)
      key_value = string.split('=', 2)
      key = key_value[0]
      value = key_value[1]? || ""
      yield key, value
    end
  end
end

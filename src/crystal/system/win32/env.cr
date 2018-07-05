require "crystal/system/windows"
require "c/winbase"

module Crystal::System::Env
  # Sets an environment variable or unsets it if *value* is `nil`.
  def self.set(key : String, value : String) : Nil
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)
    raise ArgumentError.new("Value contains null byte") if value.byte_index(0)

    if LibC.SetEnvironmentVariableW(key.to_utf16, value.to_utf16) == 0
      raise WinError.new("SetEnvironmentVariableW")
    end
  end

  # Unsets an environment variable.
  def self.set(key : String, value : Nil) : Nil
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)

    if LibC.SetEnvironmentVariableW(key.to_utf16, nil) == 0
      raise WinError.new("SetEnvironmentVariableW")
    end
  end

  # Gets an environment variable.
  def self.get(key : String) : String?
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)

    System.retry_wstr_buffer do |buffer, small_buf|
      length = LibC.GetEnvironmentVariableW(key.to_utf16, buffer, buffer.size)
      if 0 < length < buffer.size
        return String.from_utf16(buffer[0, length])
      elsif small_buf && length > 0
        next length
      elsif length == 0 && LibC.GetLastError == WinError::ERROR_ENVVAR_NOT_FOUND
        return
      else
        raise WinError.new("GetEnvironmentVariableW")
      end
    end
  end

  # Returns `true` if environment variable is set.
  def self.has_key?(key : String) : Bool
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)

    buffer = uninitialized UInt16[1]
    LibC.GetEnvironmentVariableW(key.to_utf16, buffer, buffer.size) != 0
  end

  # Iterates all environment variables.
  def self.each(&block : String, String ->)
    orig_pointer = pointer = LibC.GetEnvironmentStringsW
    raise WinError.new("GetEnvironmentStringsW") if pointer.null?

    begin
      while !pointer.value.zero?
        string, pointer = String.from_utf16(pointer)
        key_value = string.split('=', 2)
        key = key_value[0]
        value = key_value[1]? || ""
        yield key, value
      end
    ensure
      LibC.FreeEnvironmentStringsW(orig_pointer)
    end
  end
end

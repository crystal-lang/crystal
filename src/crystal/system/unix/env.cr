require "c/stdlib"

module Crystal::System::Env
  # Sets an environment variable.
  def self.set(key : String, value : String) : Nil
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)
    raise ArgumentError.new("Value contains null byte") if value.byte_index(0)

    if LibC.setenv(key, value, 1) != 0
      raise Errno.new("setenv")
    end
  end

  # Unsets an environment variable.
  def self.set(key : String, value : Nil) : Nil
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)

    if LibC.unsetenv(key) != 0
      raise Errno.new("unsetenv")
    end
  end

  # Gets an environment variable.
  def self.get(key : String) : String?
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)

    if value = LibC.getenv(key)
      String.new(value)
    end
  end

  # Returns `true` if environment variable is set.
  def self.has_key?(key : String) : Bool
    raise ArgumentError.new("Key contains null byte") if key.byte_index(0)

    !!LibC.getenv(key)
  end

  # Iterates all environment variables.
  def self.each(&block : String, String ->)
    environ_ptr = LibC.environ
    while environ_ptr
      environ_value = environ_ptr.value
      if environ_value
        key_value = String.new(environ_value).split('=', 2)
        key = key_value[0]
        value = key_value[1]? || ""
        yield key, value
        environ_ptr += 1
      else
        break
      end
    end
  end
end

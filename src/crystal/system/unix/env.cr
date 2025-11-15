require "c/stdlib"

module Crystal::System::Env
  # Sets an environment variable.
  def self.set(key : String, value : String) : Nil
    key.check_no_null_byte("key")
    value.check_no_null_byte("value")

    if LibC.setenv(key, value, 1) != 0
      raise RuntimeError.from_errno("setenv")
    end
  end

  # Unsets an environment variable.
  def self.set(key : String, value : Nil) : Nil
    key.check_no_null_byte("key")

    if LibC.unsetenv(key) != 0
      raise RuntimeError.from_errno("unsetenv")
    end
  end

  # Gets an environment variable.
  def self.get(key : String) : String?
    key.check_no_null_byte("key")

    if value = LibC.getenv(key)
      String.new(value)
    end
  end

  # Returns `true` if environment variable is set.
  def self.has_key?(key : String) : Bool
    key.check_no_null_byte("key")

    !!LibC.getenv(key)
  end

  # Iterates all environment variables.
  def self.each(&block : String, String ->)
    each_pointer do |kv_pointer|
      # this does `String.new(kv_pointer).partition('=')` without an intermediary string
      key_value = Slice.new(kv_pointer, LibC.strlen(kv_pointer))
      split_index = key_value.index!(0x3d_u8) # '='
      key = String.new(key_value[0, split_index])
      value = String.new(key_value[split_index + 1..])
      yield key, value
    end
  end

  # Iterates all environment variables as a char pointer to a "KEY=VALUE" string.
  def self.each_pointer(&block : LibC::Char* ->)
    environ_ptr = LibC.environ
    while environ_ptr
      environ_value = environ_ptr.value
      if environ_value
        yield environ_value
        environ_ptr += 1
      else
        break
      end
    end
  end

  # Creates an environment pointer for use with `execve` and similar functions.
  #
  # The behaviour is pretty straight-forward and most system lib
  # implementations generally agree on it, so there's not much controversy about
  # different flavours.
  #
  # OPTIMIZE: We could further optimize this by using the existing entry
  # pointers from `.each_pointer` instead of `.each`. And potentially we could
  # store all strings in a single buffer, and calculate the sizes for that
  # buffer and `envp` upfront to reduce overall allocations.
  def self.make_envp(env, clear_env) : LibC::Char**
    # When there are no adjustments in `env`, we can take a short cut and return
    # an empty pointer or the current environment.
    if env.nil? || env.empty?
      return clear_env ? Pointer(LibC::Char*).malloc(1) : LibC.environ
    end

    envp = Array(LibC::Char*).new

    unless clear_env
      Env.each do |key, value|
        # Skip overrides in `env`
        next if env.has_key?(key)

        envp << "#{key}=#{value}".to_unsafe
      end
    end

    env.each do |key, value|
      # `nil` value means deleting the key from the inherited environment
      next unless value

      raise ArgumentError.new("Invalid env key #{key.inspect}") if key.empty? || key.includes?('=')
      envp << "#{key.check_no_null_byte("key")}=#{value.check_no_null_byte("value")}".to_unsafe
    end

    envp.to_unsafe
  end
end

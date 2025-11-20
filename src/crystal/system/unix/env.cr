require "c/stdlib"
require "sync/rw_lock"

module Crystal::System::Env
  @@lock = Sync::RWLock.new(:unchecked)

  # Sets an environment variable.
  def self.set(key : String, value : String) : Nil
    key.check_no_null_byte("key")
    value.check_no_null_byte("value")

    if @@lock.write { LibC.setenv(key, value, 1) } != 0
      raise RuntimeError.from_errno("setenv")
    end
  end

  # Unsets an environment variable.
  def self.set(key : String, value : Nil) : Nil
    key.check_no_null_byte("key")

    if @@lock.write { LibC.unsetenv(key) } != 0
      raise RuntimeError.from_errno("unsetenv")
    end
  end

  # Gets an environment variable.
  def self.get(key : String) : String?
    key.check_no_null_byte("key")

    @@lock.read do
      if value = LibC.getenv(key)
        String.new(value)
      end
    end
  end

  # Returns `true` if environment variable is set.
  def self.has_key?(key : String) : Bool
    key.check_no_null_byte("key")

    !!@@lock.read { LibC.getenv(key) }
  end

  # Iterates all environment variables.
  def self.each(&block : String, String ->)
    # Collect variables while holding the lock because we can't trust
    # LibC.environ to be stable and don't control what &block does: it might
    # yield the current fiber while holding the lock, deadlock if it calls
    # Env.set, ...
    env = Array({String, String}).new

    @@lock.read do
      each_pointer do |kv_pointer|
        # this does `String.new(kv_pointer).partition('=')` without an intermediary string
        key_value = Slice.new(kv_pointer, LibC.strlen(kv_pointer))
        split_index = key_value.index!(0x3d_u8) # '='
        key = key_value[0, split_index]
        value = key_value[split_index + 1..]
        yield String.new(key), String.new(value)
      end
    end

    # now we can safely iterate
    env.each do |key, value|
      yield key, value
    end
  end

  # Iterates all environment variables as a char pointer to a "KEY=VALUE"
  # pointer.
  private def self.each_pointer(&block : LibC::Char* ->)
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
    # an empty pointer.
    if clear_env && (env.nil? || env.empty?)
      return Pointer(LibC::Char*).malloc(1)
    end

    envp = Array(LibC::Char*).new

    unless clear_env
      # Dup LibC.environ, skipping overrides in env.
      each do |key, value|
        next if env.try(&.has_key?(key))

        envp << "#{key}=#{value}".to_unsafe
      end
    end

    env.try(&.each do |key, value|
      # `nil` value means deleting the key from the inherited environment
      next unless value

      raise ArgumentError.new("Invalid env key #{key.inspect}") if key.empty? || key.includes?('=')
      envp << "#{key.check_no_null_byte("key")}=#{value.check_no_null_byte("value")}".to_unsafe
    end)

    envp << Pointer(LibC::Char).null

    envp.to_unsafe
  end
end

lib LibC
  $environ : Char**
  fun getenv(name : Char*) : Char*?
  fun setenv(name : Char*, value : Char*, overwrite : Int) : Int
  fun unsetenv(name : Char*) : Int
end

# `ENV` is a hash-like accessor for environment variables.
#
# __Note:__ All keys and values are strings. You must take care to cast other types
# at runtime, e.g. integer port numbers.
#
# ### Example
#
#     # Set env var PORT to a default if not already set
#     ENV["PORT"] ||= "5000"
#     # Later use that env var.
#     puts ENV["PORT"].to_i
module ENV
  # Retrieves the value for environment variable named `key` as a `String`.
  # Raises `KeyError` if the named variable does not exist.
  def self.[](key : String)
    fetch(key)
  end

  # Retrieves the value for environment variable named *key* as a `String?`.
  # Returns `nil` if the named variable does not exist.
  def self.[]?(key : String)
    fetch(key, nil)
  end

  # Sets the value for environment variable named *key* as *value*.
  # Overwrites existing environment variable if already present.
  # Returns `value` if successful, otherwise raises an exception.
  def self.[]=(key : String, value : String)
    if LibC.setenv(key, value, 1) == 0
      value
    else
      raise Errno.new("Error setting environment variable \"#{key}\"")
    end
  end

  # Returns `true` if the environment variable named *key* exists and `false`
  # if it doesn't.
  def self.has_key?(key : String)
    !!LibC.getenv(key)
  end

  # Retrieves a value corresponding to the given *key*. Raises a `KeyError` exception if the
  # key does not exist.
  def self.fetch(key)
    fetch(key) do
      raise KeyError.new "Missing ENV key: #{key.inspect}"
    end
  end

  # Retrieves a value corresponding to the given *key*. Return the second argument's value
  # if the key does not exist.
  def self.fetch(key, default)
    fetch(key) { default }
  end

  # Retrieves a value corresponding to a key. Return the value of the block if
  # the key does not exist.
  def self.fetch(key : String, &block : String -> String? | NoReturn)
    value = LibC.getenv key
    return String.new(value) if value
    yield(key)
  end

  # Returns an array of all the environment variable names.
  def self.keys
    keys = [] of String
    each { |key, v| keys << key }
    keys
  end

  # Returns an array of all the environment variable values.
  def self.values
    values = [] of String
    each { |k, value| values << value }
    values
  end

  # Removes the environment variable named *key*. Returns the previous value if
  # the environment variable existed, otherwise returns `nil`.
  def self.delete(key : String)
    if value = self[key]?
      LibC.unsetenv(key)
      value
    else
      nil
    end
  end

  # Iterates over all `KEY=VALUE` pairs of environment variables, yielding both
  # the `key` and `value`.
  #
  #     ENV.each do |key, value|
  #       puts "#{key} => #{value}"
  #     end
  def self.each
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

  def self.clear
    keys.each { |k| delete k }
  end

  # Writes the contents of the environment to *io*.
  def self.inspect(io)
    io << "{"
    found_one = false
    each do |key, value|
      io << ", " if found_one
      key.inspect(io)
      io << " => "
      value.inspect(io)
      found_one = true
    end
    io << "}"
  end
end

lib LibC
  $environ : UInt8**
  fun getenv(name : UInt8*) : UInt8*?
  fun setenv(name : UInt8*, value : UInt8*, overwrite : Int32) : Int32
  fun unsetenv(name : UInt8*) : Int32
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
    value = self[key]?
    if value
      value
    else
      raise KeyError.new "Missing ENV key: #{key}"
    end
  end

  # Retrieves the value for environment variable named `key` as a `String?`.
  # Returns `nil` if the named variable does not exist.
  def self.[]?(key : String)
    str = LibC.getenv key
    str ? String.new(str) : nil
  end

  # Sets the value for environment variable named `key` as `value`.
  # Overwrites existing environment variable if already present.
  def self.[]=(key : String, value : String)
    LibC.setenv key, value, 1
  end

  # Returns `true` if the environment variable named `key` exists and `false`
  # if it doesn't.
  def self.has_key?(key : String)
    !!LibC.getenv(key)
  end

  # Removes the environment variable named `key`. Returns the previous value if
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
        key_value = String.new(environ_value)
        key, value = key_value.split '=', 2
        yield key, value
        environ_ptr += 1
      else
        break
      end
    end
  end

  # Writes the contents of the environment to `io`.
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

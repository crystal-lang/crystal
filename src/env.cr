require "crystal/system/env"

# `ENV` is a hash-like accessor for environment variables.
#
# ### Example
#
# Assuming the following example is invoked with the `HOST=localhost` and
# `PORT=5000` environment variables:
#
# ```
# p ENV["HOST"]                       # => "localhost"
# p ENV["PORT"].to_i                  # => 5000
# p ENV.fetch("TLS_PORT", "443").to_i # => 443
# ```
#
# NOTE: All keys and values are strings. You must take care to cast other types
# at runtime, e.g. integer port numbers.
#
# ### Safety
#
# Modifying the environment in single-threaded programs is safe. Modifying the
# environment is also always safe on Windows.
#
# Modifying the environment in multi-threaded programs on other targets is
# always unsafe, and can cause a mere read to segfault! At best, memory will be
# leaked every time the environment is modified.
#
# The problem is that POSIX systems don't guarantee a thread safe implementation
# of the `getenv`, `setenv` and `putenv` libc functions. Any thread that gets an
# environment variable while another thread sets an environment variable may
# segfault. The Crystal runtime implementation of `ENV` itself is protected by a
# readers-writer lock, but we can't protect against external libraries,
# including libc calls made by the stdlib, to call `getenv` internally without
# holding the read lock while a crystal fiber with the write lock calls
# `setenv`.
#
# The only safe solution is to consider `ENV` to be immutable, and to never call
# `ENV.[]=`, `ENV.delete` or `ENV.clear` in your programs. If you really need
# to, you must make sure that no other thread has been started (beware of
# libraries that may start threads without your knowledge).
#
# NOTE: Passing environment variables to a child process should use the `env`
# arg of `Process.run` and `Process.new`.
module ENV
  extend Enumerable({String, String})

  # Retrieves the value for environment variable named *key* as a `String`.
  # Raises `KeyError` if the named variable does not exist.
  def self.[](key : String) : String
    fetch(key)
  end

  # Retrieves the value for environment variable named *key* as a `String?`.
  # Returns `nil` if the named variable does not exist.
  def self.[]?(key : String) : String?
    fetch(key, nil)
  end

  # Sets the value for environment variable named *key* as *value*.
  # Overwrites existing environment variable if already present.
  # Returns *value* if successful, otherwise raises an exception.
  # If *value* is `nil`, the environment variable is deleted.
  #
  # If *key* or *value* contains a null-byte an `ArgumentError` is raised.
  #
  # WARNING: It is recommended to never set environment variables. See the
  # Safety section of `ENV` for details.
  def self.[]=(key : String, value : String?)
    Crystal::System::Env.set(key, value)

    value
  end

  # Returns `true` if the environment variable named *key* exists and `false` if it doesn't.
  #
  # ```
  # ENV.has_key?("NOT_A_REAL_KEY") # => false
  # ENV.has_key?("PATH")           # => true
  # ```
  def self.has_key?(key : String) : Bool
    Crystal::System::Env.has_key?(key)
  end

  # Retrieves a value corresponding to the given *key*. Raises a `KeyError` exception if the
  # key does not exist.
  def self.fetch(key) : String
    fetch(key) do
      raise KeyError.new "Missing ENV key: #{key.inspect}"
    end
  end

  # Retrieves a value corresponding to the given *key*. Return the second argument's value
  # if the *key* does not exist.
  def self.fetch(key, default : T) : String | T forall T
    fetch(key) { default }
  end

  # Retrieves a value corresponding to a given *key*. Return the value of the block if
  # the *key* does not exist.
  def self.fetch(key : String, &block : String -> T) : String | T forall T
    if value = Crystal::System::Env.get(key)
      value
    else
      yield key
    end
  end

  # Returns an array of all the environment variable names.
  def self.keys : Array(String)
    keys = [] of String
    each { |key, _| keys << key }
    keys
  end

  # Returns an array of all the environment variable values.
  def self.values : Array(String)
    values = [] of String
    each { |_, value| values << value }
    values
  end

  # Removes the environment variable named *key*. Returns the previous value if
  # the environment variable existed, otherwise returns `nil`.
  #
  # WARNING: It is recommended to never delete environment variables. See the
  # Safety section of `ENV` for details.
  def self.delete(key : String) : String?
    if value = self[key]?
      Crystal::System::Env.set(key, nil)
      value
    else
      nil
    end
  end

  # Iterates over all `KEY=VALUE` pairs of environment variables, yielding both
  # the *key* and *value*.
  #
  # ```
  # ENV.each do |key, value|
  #   puts "#{key} => #{value}"
  # end
  # ```
  def self.each(& : {String, String} ->)
    Crystal::System::Env.each do |key, value|
      yield({key, value})
    end
  end

  # WARNING: It is recommended to never delete environment variables. See the
  # Safety section of `ENV` for details.
  def self.clear : Nil
    keys.each { |k| delete k }
  end

  # Writes the contents of the environment to *io*.
  def self.inspect(io)
    io << '{'
    found_one = false
    each do |key, value|
      io << ", " if found_one
      key.inspect(io)
      io << " => "
      value.inspect(io)
      found_one = true
    end
    io << '}'
  end

  def self.pretty_print(pp)
    pp.list("{", keys.sort!, "}") do |key|
      pp.group do
        key.pretty_print(pp)
        pp.text " =>"
        pp.nest do
          pp.breakable
          self[key].pretty_print(pp)
        end
      end
    end
  end
end

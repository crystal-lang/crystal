require "crystal/system/env"
require "sync/rw_lock"

# `ENV` is a hash-like accessor for environment variables.
#
# ### Example
#
# We can read the `HOST` and `PORT` environment variables and fallback to
# default values when a variable is unset:
#
# ```
# host = ENV.fetch("HOST", "localhost")
# port = ENV.fetch("PORT", "5000").to_i
# ```
#
# NOTE: All keys and values are `String`s. You must take care to cast other
# types at runtime, e.g. integer port numbers.
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
# segfault. The `ENV` object itself is internally protected by a readers-writer
# lock, but we can't protect against external libraries, including libc calls
# made by the stdlib. They might call `getenv` internally without holding the
# read lock while a crystal fiber with the write lock calls `setenv`.
#
# The only safe solution is to consider `ENV` to be immutable, and to never call
# `ENV.[]=`, `ENV.delete` or `ENV.clear` in your program. If you really need to,
# you must make sure that no other thread has been started (beware of libraries
# that may start threads) or you may call `ENV.unsafe_set`.
#
# NOTE: Passing environment variables to a child process should use the `env`
# arg of `Process.run` and `Process.new`.
module ENV
  extend Enumerable({String, String})

  # Parse the environment once during startup, while the program is still single
  # threaded, then we only ever read/write the internal hash and never call the
  # libc functions that may be safe (win32) or unsafe (unix):
  @@env = Crystal::System::Env.parse
  @@lock = Sync::RWLock.new

  # Reads an environment variable from the system environment. Returns `nil` if
  # the environment variable is unset.
  #
  # WARNING: this is thread unsafe on most targets and can cause your program to
  # segfault if another fiber or an external library is trying to write a system
  # environment variable at the same time!
  def self.unsafe_get(key : String) : String?
    @@lock.read do
      Crystal::System::Env.get(key)
    end
  end

  # Sets an environment variable to the system environment. If *value* is `nil`,
  # the environment variable will be unset.
  #
  # WARNING: this is thread unsafe on most targets and can cause your program to
  # segfault if another fiber or an external library, including libc calls made
  # by the stdlib, is trying to read a system environment variable at the same
  # time!
  def self.unsafe_set(key : String, value : String?) : String?
    @@lock.write do
      Crystal::System::Env.set(key, value)
      set_internal(key, value)
    end
    value
  end

  # :nodoc:
  def self.set_internal(key : String, value : String) : Nil
    if index = @@env.index { |k, _| k == key }
      @@env[index] = {key, value}
    else
      @@env << {key, value}
    end
  end

  # :nodoc:
  def self.set_internal(key : String, value : Nil) : Nil
    if index = @@env.index { |k, _| k == key }
      @@env.delete_at(index)
    end
  end

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
  # @Deprecated("Modifying ENV is unsafe. Consider ENV.unsafe_set if you really must change it.")
  def self.[]=(key : String, value : String?)
    unsafe_set(key, value)
  end

  # Returns `true` if the environment variable named *key* exists and `false` if it doesn't.
  #
  # ```
  # ENV.has_key?("NOT_A_REAL_KEY") # => false
  # ENV.has_key?("PATH")           # => true
  # ```
  def self.has_key?(key : String) : Bool
    @@lock.read { @@env.any? { |k, _| k == key } }
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
    if entry = @@lock.read { @@env.find { |k, _| k == key } }
      entry[1]
    else
      yield key
    end
  end

  # Returns an array of all the environment variable names.
  def self.keys : Array(String)
    @@lock.read { @@env.map { |k, _| k } }
  end

  # Returns an array of all the environment variable values.
  def self.values : Array(String)
    @@lock.read { @@env.map { |_, v| v } }
  end

  # Removes the environment variable named *key*. Returns the previous value if
  # the environment variable existed, otherwise returns `nil`.
  #
  # @Deprecated("Modifying ENV is unsafe. Consider ENV.unsafe_set if you really must change it.")
  def self.delete(key : String) : String?
    @@lock.write do
      Crystal::System::Env.set(key, nil)
      if index = @@env.index { |k, _| k == key }
        entry = @@env.delete_at(index)
        entry[1]
      end
    end
  end

  # Iterates all the environment variables, yielding both the *key* and *value*.
  #
  # ```
  # ENV.each do |key, value|
  #   puts "#{key} => #{value}"
  # end
  # ```
  def self.each(& : {String, String} ->)
    @@lock.read do
      @@env.each { |(key, value)| yield({key, value}) }
    end
  end

  # @Deprecated("Modifying ENV is unsafe. Consider ENV.unsafe_set if you really must change it.")
  def self.clear : Nil
    @@lock.write do
      @@env.each { |k, _| Crystal::System::Env.set(k, nil) }
      @@env.clear
    end
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

lib LibC
  $environ : Char**
  fun getenv(name : Char*) : Char*?
  fun setenv(name : Char*, value : Char*, overwrite : Int) : Int
  fun unsetenv(name : Char*) : Int
end

module ENV
  def self.[](key : String)
    value = self[key]?
    if value
      value
    else
      raise KeyError.new "Missing ENV key: #{key}"
    end
  end

  def self.[]?(key : String)
    str = LibC.getenv key
    str ? String.new(str) : nil
  end

  def self.[]=(key : String, value : String)
    LibC.setenv key, value, 1
  end

  def self.has_key?(key : String)
    !!LibC.getenv(key)
  end

  def self.delete(key : String)
    if value = self[key]?
      LibC.unsetenv(key)
      value
    else
      nil
    end
  end

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

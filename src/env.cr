lib C
  $environ : UInt8**
  fun getenv(name : UInt8*) : UInt8*?
  fun setenv(name : UInt8*, value : UInt8*, overwrite : Int32) : Int32
  fun unsetenv(name : UInt8*) : Int32
end

module ENV
  def self.[](key : String)
    value = self[key]?
    if value
      value
    else
      raise MissingKey.new "Missing ENV key: #{key}"
    end
  end

  def self.[]?(key : String)
    str = C.getenv key
    str ? String.new(str) : nil
  end

  def self.[]=(key : String, value : String)
    C.setenv key, value, 1
  end

  def self.has_key?(key : String)
    !!C.getenv(key)
  end

  def self.delete(key : String)
    if value = self[key]?
      C.unsetenv(key)
      value
    else
      nil
    end
  end

  def self.each
    environ_ptr = C.environ
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

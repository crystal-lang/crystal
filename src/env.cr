lib LibC
  ifdef darwin || linux
    $environ : UInt8**
    fun getenv(name : UInt8*) : UInt8*?
    fun setenv(name : UInt8*, value : UInt8*, overwrite : Int32) : Int32
    fun unsetenv(name : UInt8*) : Int32
  elsif windows
    $wenviron = _wenviron : UInt16**
    fun wgetenv = _wgetenv(name : UInt16*) : UInt16*?
    fun wputenv = _wputenv_s(name : UInt16*, value : UInt16*) : Int32
  end
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
    ifdef darwin || linux
      str = LibC.getenv(key)
    elsif windows
        str = LibC.wgetenv(key.to_utf16)
    end
    str ? String.new(str) : nil
  end

  def self.[]=(key : String, value : String)
    ifdef darwin || linux
      LibC.setenv(key, value, 1)
    elsif windows
      LibC.wputenv(key.to_utf16, value.to_utf16)
    end
  end

  def self.has_key?(key : String)
    ifdef darwin || linux
      !!LibC.getenv(key)
    elsif windows
      !!LibC.wgetenv(key.to_utf16)
    end
  end

  ifdef darwin || linux
    def self.delete(key : String)
      if value = self[key]?
        LibC.unsetenv(key)
        value
      else
        nil
      end
    end
  elsif windows
    #-- TODO
  end

  def self.each
    ifdef darwin || linux
      environ_ptr = LibC.environ
    elsif windows
      environ_ptr = LibC.wenviron
    end
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

lib C
  fun getenv(name : UInt8*) : UInt8*?
  fun setenv(name : UInt8*, value : UInt8*, overwrite : Int32) : Int32
end

module ENV
  def self.[](name)
    str = C.getenv name
    str ? String.new(str) : nil
  end

  def self.[]=(name, value)
    C.setenv name, value, 1
  end
end

lib C
  fun getenv(name : Char*) : Char*
  fun setenv(name : Char*, value : Char*, overwrite : Int32) : Int32
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

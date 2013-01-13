lib C
  fun getenv(name : Char*) : Char*
  fun setenv(name : Char*, value : Char*, overwrite : Int) : Int
end

module ENV
  def self.[](name)
    str = C.getenv name
    str ? String.from_cstr(str) : nil
  end

  def self.[]=(name, value)
    C.setenv name, value, 1
  end
end

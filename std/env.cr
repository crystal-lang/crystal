lib C
  fun getenv(name : Char*) : Char*
  fun setenv(name : Char*, value : Char*, overwrite : Int) : Int
end

module ENV
  def self.[](name)
    String.from_cstr(C.getenv name)
  end

  def self.[]=(name, value)
    C.setenv name, value, 1
  end
end

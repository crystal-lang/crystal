lib C
  fun getenv(name : Char*) : Char*
  fun setenv(name : Char*, value : Char*, overwrite : Int) : Int
end

module ENV
  def self.[](name)
    String.from_cstr(C.getenv name.cstr)
  end

  def self.[]=(name, value)
    C.setenv name.cstr, value.cstr, 1
  end
end

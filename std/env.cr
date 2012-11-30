lib C
  fun getenv(name : String) : String
  fun setenv(name : String, value : String, overwrite : Int) : Int
end

class ENV
  def self.[](name)
    C.getenv name
  end

  def self.[]=(name, value)
    C.setenv name, value, 1
  end
end

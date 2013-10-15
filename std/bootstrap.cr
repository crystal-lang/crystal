lib C
  fun exit(s : Int32) : Int32
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int32
end

def exit(status = 0)
  C.exit status
end

def print(c)
  C.putchar c
end

def puts(obj = "")
  C.puts obj.to_s
end

class String
  def cstr
    @c.ptr
  end

  def to_s
    self
  end
end

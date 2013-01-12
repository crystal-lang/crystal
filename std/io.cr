lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int
  fun printf(str : Char*, ...) : Char
  fun sprintf(str : Char*, template : Char*, ...) : Char
end

def print(obj : Char)
  C.putchar obj
end

def print(obj : Int)
  C.printf "%d", obj
end

def print(obj : Long)
  C.printf "%ld", obj
end

def print(obj : Float)
  C.printf "%f", obj
end

def print(obj : Double)
  C.printf "%g", obj
end

def print(obj)
  C.printf obj.to_s
end

def puts(obj : Char)
  C.printf "%c\n", obj
end

def puts(obj : Int)
  C.printf "%d\n", obj
end

def puts(obj : Long)
  C.printf "%ld\n", obj
end

def puts(obj : Float)
  C.printf "%f\n", obj
end

def puts(obj : Double)
  C.printf "%g\n", obj
end

def puts(obj = "")
  C.puts obj.to_s
end

def p(obj)
  puts obj.inspect
end

macro pp(var)
  "puts \"#{var} = ##{#{var}}\""
end

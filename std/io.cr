lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int32
  fun printf(str : Char*, ...) : Char
  fun sprintf(str : Char*, template : Char*, ...) : Char
  fun system(str : Char*) : Int32
end

def print(obj : Char)
  C.putchar obj
  nil
end

def print(obj : Int32)
  C.printf "%d", obj
  nil
end

def print(obj : Int64)
  C.printf "%ld", obj
  nil
end

def print(obj : Float32)
  C.printf "%f", obj
  nil
end

def print(obj : Float64)
  C.printf "%g", obj
  nil
end

def print(obj)
  C.printf obj.to_s
  nil
end

def puts(obj : Char)
  C.printf "%c\n", obj
  nil
end

def puts(obj : Int8)
  C.printf "%hhd\n", obj
  nil
end

def puts(obj : Int16)
  C.printf "%hd\n", obj
  nil
end

def puts(obj : Int32)
  C.printf "%d\n", obj
  nil
end

def puts(obj : Int64)
  C.printf "%ld\n", obj
  nil
end

def puts(obj : Float32)
  C.printf "%f\n", obj
  nil
end

def puts(obj : Float64)
  C.printf "%g\n", obj
  nil
end

def puts(obj = "")
  C.puts obj.to_s
  nil
end

def p(obj)
  puts obj.inspect
  obj
end

def system(command)
  C.system command
end

macro pp(var)
  "puts \"#{var} = ##{#{var}}\""
end

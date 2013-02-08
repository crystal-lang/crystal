lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int
  fun printf(str : Char*, ...) : Char
  fun sprintf(str : Char*, template : Char*, ...) : Char
  fun system(str : Char*) : Int
end

def print(obj : Char)
  C.putchar obj
  nil
end

def print(obj : Int)
  C.printf "%d", obj
  nil
end

def print(obj : Long)
  C.printf "%ld", obj
  nil
end

def print(obj : Float)
  C.printf "%f", obj
  nil
end

def print(obj : Double)
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

def puts(obj : Int)
  C.printf "%d\n", obj
  nil
end

def puts(obj : Long)
  C.printf "%ld\n", obj
  nil
end

def puts(obj : Float)
  C.printf "%f\n", obj
  nil
end

def puts(obj : Double)
  C.printf "%g\n", obj
  nil
end

def puts(obj : Enumerable)
  obj.each do |item|
    puts item
  end
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

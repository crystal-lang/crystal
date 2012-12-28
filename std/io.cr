lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int
end

def print(obj)
  C.putchar obj
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

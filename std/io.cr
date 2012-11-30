lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : String) : Int
end

def puts(obj = "")
  C.puts obj.to_s
end

def p(obj)
  puts obj.inspect
end

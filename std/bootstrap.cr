lib C
  fun exit(s : Int32) : Int32
  fun putchar(c : Char) : Char
end

def exit(status = 0)
  C.exit status
end

def print(c)
  C.putchar c
end

def puts
  C.putchar '\n'
end

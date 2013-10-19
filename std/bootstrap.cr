lib C
  fun exit(s : Int32) : Int32
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int32
  fun printf(str : Char*, ...) : Char
end

class String
  def cstr
    @c.ptr
  end

  def length
    @length
  end

  def to_s
    self
  end
end

class Pointer(T)
  def +(offset : Int32)
    Pointer(T).new((address + T.byte_size * offset).to_u64)
  end

  def [](offset)
    (self + offset).value
  end

  def []=(offset, value : T)
    (self + offset).value = value
  end
end

def exit(status = 0)
  C.exit status
end

def print(c)
  C.putchar c
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

def puts(obj : UInt8)
  C.printf "%hhu\n", obj
  nil
end

def puts(obj : UInt16)
  C.printf "%hu\n", obj
  nil
end

def puts(obj : UInt32)
  C.printf "%u\n", obj
  nil
end

def puts(obj : UInt64)
  C.printf "%lu\n", obj
  nil
end

def puts(obj : Float32)
  C.printf "%g\n", obj.to_f64
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

lib CrystalMain
  fun __crystal_main(argc : Int32, argv : Char**)
end

fun main(argc : Int32, argv : Char**) : Int32
  CrystalMain.__crystal_main(argc, argv)
  0
end


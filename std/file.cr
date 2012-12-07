lib C
  type File : Void*

  fun fopen(filename : String, mode : String) : File
  fun fputs(str : String, file : File) : Int
  fun fclose(file : File) : Int
  fun feof(file : File) : Int
  fun getline(linep : Char**, linecap : Long*, file : File) : Long
end

class File
  def initialize(filename, mode)
    @file = C.fopen filename, mode
  end

  def print(string)
    C.fputs string, @file
  end

  def puts(string)
    print string
    C.fputs "\n", @file
  end

  def gets
    buffer = Pointer.malloc(0).as(Char)
    buffer_ptr = buffer.ptr
    cap = 0L
    length = C.getline(buffer_ptr, cap.ptr, @file)
    length > 0 ? buffer.as(String) : nil
  end

  def eof?
    C.feof(@file) != 0
  end

  def close
    C.fclose @file
  end

  def self.open(filename, mode)
    file = File.new filename, mode
    yield file
    file.close
  end
end


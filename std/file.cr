lib C
  type File : Void*

  fun fopen(filename : Char*, mode : Char*) : File
  fun fputs(str : Char*, file : File) : Int32
  fun fclose(file : File) : Int32
  fun feof(file : File) : Int32
  fun getline(linep : Char**, linecap : Int64*, file : File) : Int64
  fun fflush(file : File) : Int32
  fun fseek(file : File, offset : Int64, whence : Int32) : Int32
  fun ftell(file : File) : Int64
  fun fread(buffer : Char*, size : Int64, nitems : Int64, file : File) : Int32

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2
end

abstract class IO
  def print(string)
    C.fputs string, output
  end

  def puts(string)
    print string
    C.fputs "\n", output
  end

  def gets
    buffer = Pointer(Char).malloc(0)
    buffer_ptr = buffer.ptr
    cap = 0_i64
    length = C.getline(buffer_ptr, cap.ptr, input)
    length > 0 ? String.from_cstr(buffer) : nil
  end

  def eof?
    C.feof(input) != 0
  end

  def flush
    C.fflush output
  end
end

class File < IO
  def initialize(filename, mode)
    @file = C.fopen filename, mode
  end

  def self.open(filename, mode)
    file = File.new filename, mode
    yield file
    file.close
  end

  def self.read(filename)
    f = C.fopen(filename, "r")
    C.fseek(f, 0_i64, C::SEEK_END)
    size = C.ftell(f)
    C.fseek(f, 0_i64, C::SEEK_SET)
    str = Pointer(Char).malloc(size + 1)
    C.fread(str, size, 1_i64, f)
    C.fclose(f)
    String.from_cstr(str, size.to_i32)
  end

  def input
    @file
  end

  def output
    @file
  end

  def close
    C.fclose @file
  end
end


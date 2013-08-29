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
  fun access(filename : Char*, how : Int32) : Int32
  fun realpath(path : Char*, resolved_path : Char*) : Char*

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
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
  SEPARATOR = '/'

  def initialize(filename, mode)
    @file = C.fopen filename, mode
  end

  def self.exists?(filename)
    C.access(filename, C::F_OK) == 0
  end

  def self.dirname(filename)
    index = filename.rindex SEPARATOR
    return "." if index == -1
    return "/" if index == 0
    filename[0, index]
  end

  def self.basename(filename)
    return "" if filename.length == 0

    last = filename.length - 1
    last -= 1 if filename[last] == SEPARATOR

    index = filename.rindex SEPARATOR, last
    return filename if index == -1

    filename[index + 1, last - index]
  end

  def self.basename(filename, suffix)
    basename = basename(filename)
    basename = basename[0, basename.length - suffix.length] if basename.ends_with?(suffix)
    basename
  end

  def self.extname(filename)
    dot_index = filename.rindex('.')

    if dot_index == -1 ||
       dot_index == filename.length - 1 ||
       (dot_index > 0 && filename[dot_index - 1] == SEPARATOR)
      return ""
    end

    return filename[dot_index, filename.length - dot_index]
  end

  def self.expand_path(filename)
    str = C.realpath(filename, nil)
    length = C.strlen(str)
    String.from_cstr(str, length)
  end

  def self.open(filename, mode)
    file = File.new filename, mode
    begin
      yield file
    ensure
      file.close
    end
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


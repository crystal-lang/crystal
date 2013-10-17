class File
  include IO

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
    String.new(str, length)
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
    String.new(str, size.to_i32)
  end

  def self.read_lines(filename)
    contents = read(filename)
    contents.split("\n")
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


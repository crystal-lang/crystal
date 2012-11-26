lib C
  type File : Pointer

  fun fopen(filename : String, mode : String) : File
  fun fputs(str : String, file : File) : Int
  fun fclose(file : File) : Int
end

class File
  def initialize(filename, mode)
    @file = C.fopen filename, mode
  end

  def ptr
    @file
  end

  def print(string)
    C.fputs string, @file
  end

  def puts(string)
    print string
    C.fputs "\n", @file
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


lib C
  type File : Void*

  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : Char*) : Int32
  fun printf(str : Char*, ...) : Char
  fun system(str : Char*) : Int32

  fun fopen(filename : Char*, mode : Char*) : File
  fun fputs(str : Char*, file : File) : Int32
  fun fclose(file : File) : Int32
  fun feof(file : File) : Int32
  fun getline(linep : Char**, linecap : Int64*, file : File) : Int64
  fun fflush(file : File) : Int32
  fun fread(buffer : Char*, size : C::SizeT, nitems : C::SizeT, file : File) : Int32
  fun access(filename : Char*, how : Int32) : Int32
  fun realpath(path : Char*, resolved_path : Char*) : Char*
  fun fdopen(fd : Int32, mode : Char*) : File
  fun fgets(buffer : Char*, maxlength : Int32, file : File) : Char*
  fun unlink(filename : Char*) : Char*
  fun popen(command : Char*, mode : Char*) : File
  fun pclose(stream : File) : Int32
  fun execl(path : Char*, arg0 : Char*, ...) : Int32
  fun waitpid(pid : Int32, stat_loc : Int32*, options : Int32) : Int32
  fun open(path : Char*, oflag : Int32) : Int32
  fun dup2(fd : Int32, fd2 : Int32) : Int32

  ifdef x86_64
    fun fseeko(file : File, offset : Int64, whence : Int32) : Int32
    fun ftello(file : File) : Int64
  else
    fun fseeko = fseeko64(file : File, offset : Int64, whence : Int32) : Int32
    fun ftello = ftello64(file : File) : Int64
  end

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
end

module IO
  def print(string)
    C.fputs string, output
  end

  def puts(string)
    print string
    C.fputs "\n", output
  end

  def gets
    String.build do |str|
      while true
        buffer = Pointer(Char).malloc(256)
        return nil unless C.fgets(buffer, 256, input)
        read = String.new(buffer)
        str << read
        break if read.ends_with?('\n')
      end
    end
  end

  def eof?
    C.feof(input) != 0
  end

  def flush
    C.fflush output
  end
end

class FileDescriptorStream
  include IO

  def initialize(fd, mode)
    @fd = C.fdopen(fd, mode)
  end

  def input
    @fd
  end

  def output
    @fd
  end
end

class FileStream
  include IO

  def initialize(@file)
  end

  def input
    @file
  end
end

STDIN = FileDescriptorStream.new(0, "r")
STDOUT = FileDescriptorStream.new(1, "w")
STDERR = FileDescriptorStream.new(2, "w")

def gets
  STDIN.gets
end

def print(obj : Char)
  C.putchar obj
  nil
end

def print(obj : Int32)
  C.printf "%d", obj
  nil
end

def print(obj : Int64)
  C.printf "%ld", obj
  nil
end

def print(obj : Float32)
  C.printf "%f", obj
  nil
end

def print(obj : Float64)
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
  C.printf "%lld\n", obj
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
  C.printf "%llu\n", obj
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

def p(obj)
  puts obj.inspect
  obj
end

def system(command)
  pid = fork do
    # Redirect STDOUT to /dev/null
    null = C.open("/dev/null", 1)
    C.dup2(null, 1)

    C.execl("/bin/sh", command, "-c", command, nil)
  end

  if pid == -1
    raise Errno.new("Error executing system command '#{command}'")
  end

  C.waitpid(pid, out stat, 0)
  stat
end

def system2(command)
  pipe = C.popen(command, "r")
  unless pipe
    raise Errno.new("Error executing system command '#{command}'")
  end
  begin
    stream = FileStream.new(pipe)
    output = [] of String
    while line = stream.gets
      output << line.chomp
    end
    output
  ensure
    $exit = C.pclose(pipe)
  end
end

macro pp(var)
  "puts \"#{var} = \#{#{var}}\""
end

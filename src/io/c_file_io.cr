lib C
  type File : Void*

  fun fopen(filename : UInt8*, mode : UInt8*) : File
  fun fwrite(buf : UInt8*, size : C::SizeT, count : C::SizeT, fp : File) : SizeT
  fun fclose(file : File) : Int32
  fun feof(file : File) : Int32
  fun fflush(file : File) : Int32
  fun fread(buffer : UInt8*, size : C::SizeT, nitems : C::SizeT, file : File) : Int32
  fun access(filename : UInt8*, how : Int32) : Int32
  fun fileno(file : File) : Int32
  fun realpath(path : UInt8*, resolved_path : UInt8*) : UInt8*
  fun unlink(filename : UInt8*) : Int32
  fun popen(command : UInt8*, mode : UInt8*) : File
  fun pclose(stream : File) : Int32
  fun fileno(stream : File) : Int32

  fun rename(oldname : UInt8*, newname : UInt8*) : Int32
  fun mkstemp(result : UInt8*) : Int32

  ifdef x86_64
    fun fseeko(file : File, offset : Int64, whence : Int32) : Int32
    fun ftello(file : File) : Int64
  else
    fun fseeko = fseeko64(file : File, offset : Int64, whence : Int32) : Int32
    fun ftello = ftello64(file : File) : Int64
  end

  ifdef darwin
    $stdin = __stdinp : File
    $stdout = __stdoutp : File
    $stderr = __stderrp : File
  elsif linux
    $stdin : File
    $stdout : File
    $stderr : File
  end

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
end

struct CFileIO
  include IO

  def initialize(@file)
  end

  def read(slice : Slice(UInt8), count)
    C.fread(slice.pointer(count), 1.to_sizet, count.to_sizet, @file)
  end

  def write(slice : Slice(UInt8), count)
    C.fwrite(slice.pointer(count), 1.to_sizet, count.to_sizet, @file)
  end

  def flush
    C.fflush @file
  end

  def close
    C.fclose @file
  end

  def fd
    C.fileno(@file)
  end
end

STDIN = CFileIO.new(C.stdin)
STDOUT = CFileIO.new(C.stdout)
STDERR = CFileIO.new(C.stderr)

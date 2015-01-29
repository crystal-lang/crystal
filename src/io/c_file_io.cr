lib LibC
  ifdef windows
    struct IoBuf
      data : Int32[8]
    end
    type File = IoBuf*
  else
    type File = Void*
  end

  fun fopen(filename : UInt8*, mode : UInt8*) : File
  fun fwrite(buf : UInt8*, size : LibC::SizeT, count : LibC::SizeT, fp : File) : SizeT
  fun fclose(file : File) : Int32
  fun feof(file : File) : Int32
  fun fflush(file : File) : Int32
  fun fread(buffer : UInt8*, size : LibC::SizeT, nitems : LibC::SizeT, file : File) : Int32
  fun access(filename : UInt8*, how : Int32) : Int32
  fun fileno(file : File) : Int32
  fun realpath(path : UInt8*, resolved_path : UInt8*) : UInt8*
  fun unlink(filename : UInt8*) : Int32
  fun popen(command : UInt8*, mode : UInt8*) : File
  fun pclose(stream : File) : Int32
  fun fileno(stream : File) : Int32

  fun rename(oldname : UInt8*, newname : UInt8*) : Int32

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
  elsif windows
    fun __iob_func : File
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
    LibC.fread(slice.pointer(count), LibC::SizeT.cast(1), LibC::SizeT.cast(count), @file)
  end

  def write(slice : Slice(UInt8), count)
    LibC.fwrite(slice.pointer(count), LibC::SizeT.cast(1), LibC::SizeT.cast(count), @file)
  end

  def flush
    LibC.fflush @file
  end

  def close
    LibC.fclose @file
  end

  def fd
    LibC.fileno(@file)
  end

  def tty?
    LibC.isatty(fd) == 1
  end
end

ifdef windows
  STDIN = CFileIO.new(LibC.__iob_func)
  STDOUT = CFileIO.new(LibC.__iob_func + 1)
  STDERR = CFileIO.new(LibC.__iob_func + 2)
else
  STDIN = CFileIO.new(LibC.stdin)
  STDOUT = CFileIO.new(LibC.stdout)
  STDERR = CFileIO.new(LibC.stderr)
end

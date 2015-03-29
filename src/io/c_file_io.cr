lib LibC
  ifdef darwin || linux
    type File = Void*
  elsif windows
    struct IoBuf
      data : Int32[8]
    end
    type File = IoBuf*
  end

  fun fopen(filename : UInt8*, mode : UInt8*) : File
  fun fwrite(buf : UInt8*, size : SizeT, count : SizeT, fp : File) : SizeT
  fun fclose(file : File) : Int32
  fun feof(file : File) : Int32
  fun fflush(file : File) : Int32
  fun fread(buffer : UInt8*, size : SizeT, nitems : SizeT, file : File) : SizeT
  fun rename(oldname : UInt8*, newname : UInt8*) : Int32

  ifdef darwin || linux
    fun access(filename : UInt8*, how : Int32) : Int32
    fun fileno(file : File) : Int32
    fun unlink(filename : UInt8*) : Int32
    fun popen(command : UInt8*, mode : UInt8*) : File
    fun pclose(stream : File) : Int32
    fun realpath(path : UInt8*, resolved_path : UInt8*) : UInt8*

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
  elsif windows
    fun wrename = _wrename(oldname : UInt16*, newname : UInt16*) : Int32
    fun wfopen = _wfopen(filename : UInt16*, mode : UInt16*) : File
    fun waccess = _waccess(filename : UInt16*, how : Int32) : Int32
    fun fileno = _fileno(file : File) : Int32
    fun wunlink = _wunlink(filename : UInt16*) : Int32
    fun wpopen = _wpopen(command : UInt16*, mode : UInt8*) : File
    fun pclose = _pclose(stream : File) : Int32
    fun wfullpath = _wfullpath(buf : UInt16*, path : UInt16*, size : SizeT) : UInt16*

    fun fseeko = _fseeki64(file : File, offset : Int64, origin : Int32) : Int32
    fun ftello = _ftelli64(file : File) : Int64

    fun iob_func = __iob_func : File
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
    LibC.fileno @file
  end

  def tty?
    LibC.isatty(fd) == 1
  end

  def to_fd_io
    FileDescriptorIO.new fd
  end
end

ifdef darwin || linux
  STDIN = CFileIO.new(LibC.stdin)
  STDOUT = CFileIO.new(LibC.stdout)
  STDERR = CFileIO.new(LibC.stderr)
elsif windows
  STDIN = CFileIO.new(LibC.iob_func)
  STDOUT = CFileIO.new(LibC.iob_func + 1)
  STDERR = CFileIO.new(LibC.iob_func + 2)
end

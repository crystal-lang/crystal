require "c/stdint"

lib LibC
  fun _isatty(fd : Int) : Int
  fun _close(fd : Int) : Int
  fun _waccess_s(path : WCHAR*, mode : Int) : ErrnoT
  fun _wexecvp(cmdname : WCHAR*, argv : WCHAR**) : IntPtrT
  fun _get_osfhandle(fd : Int) : IntPtrT
  fun _dup2(fd1 : Int, fd2 : Int) : Int
  fun _open_osfhandle(osfhandle : HANDLE, flags : LibC::Int) : LibC::Int
  fun _setmode(fd : LibC::Int, mode : LibC::Int) : LibC::Int

  # unused
  fun _write(fd : Int, buffer : UInt8*, count : UInt) : Int
  fun _read(fd : Int, buffer : UInt8*, count : UInt) : Int
  fun _lseeki64(fd : Int, offset : Int64, origin : Int) : Int64
  fun _wopen(filename : WCHAR*, oflag : Int, ...) : Int
  fun _wchmod(filename : WCHAR*, pmode : Int) : Int
  fun _wunlink(filename : WCHAR*) : Int
  fun _wmktemp_s(template : WCHAR*, sizeInChars : SizeT) : ErrnoT
  fun _chsize_s(fd : Int, size : Int64) : ErrnoT
  fun _pipe(pfds : Int*, psize : UInt, textmode : Int) : Int
  fun _commit(fd : Int) : Int
end

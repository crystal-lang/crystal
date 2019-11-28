require "c/stdint"

lib LibC
  fun _write(fd : Int, buffer : UInt8*, count : UInt) : Int
  fun _read(fd : Int, buffer : UInt8*, count : UInt) : Int
  fun _lseek(fd : Int, offset : Long, origin : Int) : Long
  fun _isatty(fd : Int) : Int
  fun _close(fd : Int) : Int
  fun _wopen(filename : WCHAR*, oflag : Int, ...) : Int
  fun _waccess_s(path : WCHAR*, mode : Int) : ErrnoT
  fun _wchmod(filename : WCHAR*, pmode : Int) : Int
  fun _wunlink(filename : WCHAR*) : Int
  fun _wmktemp_s(template : WCHAR*, sizeInChars : SizeT) : ErrnoT
  fun _wrename(oldname : WCHAR*, newname : WCHAR*) : Int
  fun _chsize(fd : Int, size : Long) : Int
  fun _get_osfhandle(fd : Int) : IntPtrT
  fun _open_osfhandle(osfhandle : IntPtrT, flags : Int) : Int
  fun _pipe(pfds : Int*, psize : UInt, textmode : Int) : Int
  fun _dup(fd : Int) : Int
  fun _dup2(fd1 : Int, fd2 : Int) : Int
end

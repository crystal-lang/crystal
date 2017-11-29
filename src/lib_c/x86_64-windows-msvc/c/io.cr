lib LibC
  fun _write(fd : Int, buffer : UInt8*, count : UInt) : Int
  fun _read(fd : Int, buffer : UInt8*, count : UInt) : Int
  fun _lseek(fd : Int, offset : Long, origin : Int) : Long
  fun _isatty(fd : Int) : Int
  fun _close(fd : Int) : Int
end

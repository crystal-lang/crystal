lib LibC
  fun access(filename : UInt8*, how : Int32) : Int32
  fun realpath(path : UInt8*, resolved_path : UInt8*) : UInt8*
  fun unlink(filename : UInt8*) : Int32
  fun rename(oldname : UInt8*, newname : UInt8*) : Int32

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  F_OK = 0
  X_OK = 1 << 0
  W_OK = 1 << 1
  R_OK = 1 << 2
end

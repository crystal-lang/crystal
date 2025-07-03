require "./sys/types"
require "./stdint"

lib LibC
  F_OK                =  0
  R_OK                =  1
  W_OK                =  2
  X_OK                =  4
  SC_CLK_TCK          =  2
  SC_NPROCESSORS_ONLN = 84

  fun access(x0 : Char*, x1 : Int) : Int
  fun chdir(x0 : Char*) : Int
  fun fchown(x0 : Int, x1 : UidT, x2 : GidT) : Int
  fun close(fd : Int) : Int
  fun _exit(x0 : Int) : NoReturn
  fun fdatasync(x0 : Int) : Int
  fun fsync(x0 : Int) : Int
  fun ftruncate(x0 : Int, x1 : OffT) : Int
  fun getcwd(x0 : Char*, x1 : SizeT) : Char*
  fun isatty(x0 : Int) : Int
  fun link(x0 : Char*, x1 : Char*) : Int
  fun lseek(x0 : Int, x1 : OffT, x2 : Int) : OffT
  fun read(x0 : Int, x1 : Void*, x2 : SizeT) : SSizeT
  fun pread(x0 : Int, x1 : Void*, x2 : SizeT, x3 : OffT) : SSizeT
  fun readlink(x0 : Char*, x1 : Char*, x2 : SizeT) : SSizeT
  fun rmdir(x0 : Char*) : Int
  fun sleep(x0 : UInt) : UInt
  fun symlink(x0 : Char*, x1 : Char*) : Int
  fun sysconf(x0 : Int) : Long
  fun unlink(x0 : Char*) : Int
  fun write(x0 : Int, x1 : Void*, x2 : SizeT) : SSizeT
end

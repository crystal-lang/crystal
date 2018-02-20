require "./sys/types"
require "./stdint"

lib LibC
  F_OK =    0 # test for existence of file
  X_OK = 0x01 # test for execute or search permission
  W_OK = 0x02 # test for write permission
  R_OK = 0x04 # test for read permission

  SC_CLK_TCK = 3

  fun access(path : Char*, amode : Int) : Int
  fun chdir(path : Char*) : Int
  fun chown(path : Char*, owner : UidT, group : GidT) : Int
  fun close(d : Int) : Int
  fun dup2(oldd : Int, newd : Int) : Int
  fun _exit(status : Int) : NoReturn
  fun execvp(file : Char*, argv : Char**) : Int
  @[ReturnsTwice]
  fun fork : PidT
  fun ftruncate(fd : Int, length : OffT) : Int
  fun getcwd(buf : Char*, size : SizeT) : Char*
  fun gethostname(name : Char*, namelen : SizeT) : Int
  fun getpgid(pid : PidT) : PidT
  fun getpid : PidT
  fun getppid : PidT
  fun isatty(fd : Int) : Int
  fun lchown(path : Char*, owner : UidT, group : GidT) : Int
  fun link(name1 : Char*, name2 : Char*) : Int
  fun lockf(filedes : Int, function : Int, off_t : OffT) : Int
  fun lseek(filedes : Int, offset : OffT, whence : Int) : OffT
  fun pipe(fildes : Int*) : Int
  fun read(d : Int, buf : Void*, nbytes : SizeT) : SSizeT
  fun pread(d : Int, buf : Void*, nbytes : SizeT, offset : OffT) : SSizeT
  fun rmdir(path : Char*) : Int
  fun symlink(name1 : Char*, name2 : Char*) : Int
  fun syscall(number : Int, ...) : Int
  fun sysconf(name : Int) : Long
  fun unlink(path : Char*) : Int
  fun write(d : Int, buf : Void*, nbytes : SizeT) : SSizeT
end

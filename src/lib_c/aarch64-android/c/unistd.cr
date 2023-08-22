require "./sys/types"
require "./stdint"

lib LibC
  F_OK                =  0
  R_OK                =  4
  W_OK                =  2
  X_OK                =  1
  SC_CLK_TCK          =  6
  SC_NPROCESSORS_ONLN = 97
  SC_PAGESIZE         = 39

  fun chroot(__path : Char*) : Int
  fun access(__path : Char*, __mode : Int) : Int
  fun chdir(__path : Char*) : Int
  fun chown(__path : Char*, __owner : UidT, __group : GidT) : Int
  fun fchown(__fd : Int, __owner : UidT, __group : GidT) : Int
  fun close(__fd : Int) : Int
  fun dup2(__old_fd : Int, __new_fd : Int) : Int
  fun _exit(__status : Int) : NoReturn
  fun execvp(__file : Char*, __argv : Char**) : Int
  fun fdatasync(__fd : Int) : Int
  @[ReturnsTwice]
  fun fork : PidT
  fun fsync(__fd : Int) : Int
  fun ftruncate(__fd : Int, __length : OffT) : Int
  fun getcwd(__buf : Char*, __size : SizeT) : Char*
  fun gethostname(__buf : Char*, __buf_size : SizeT) : Int
  fun getpgid(__pid : PidT) : PidT
  fun getpid : PidT
  fun getppid : PidT
  fun getuid : UidT
  fun setuid(uid : UidT) : Int
  fun isatty(__fd : Int) : Int
  fun ttyname_r(__fd : Int, __buf : Char*, __buf_size : SizeT) : Int
  fun lchown(__path : Char*, __owner : UidT, __group : GidT) : Int
  fun link(__old_path : Char*, __new_path : Char*) : Int
  {% if ANDROID_API >= 24 %}
    fun lockf(__fd : Int, __cmd : Int, __length : OffT) : Int
  {% end %}
  fun lseek(__fd : Int, __offset : OffT, __whence : Int) : OffT
  fun pipe(__fds : Int[2]) : Int
  fun read(__fd : Int, __buf : Void*, __count : SizeT) : SSizeT
  fun pread(__fd : Int, __buf : Void*, __count : SizeT, __offest : OffT) : SSizeT
  fun rmdir(__path : Char*) : Int
  fun symlink(__old_path : Char*, __new_path : Char*) : Int
  fun readlink(__path : Char*, __buf : Char*, __buf_size : SizeT) : SSizeT
  fun syscall(__number : Long, ...) : Long
  fun sysconf(__name : Int) : Long
  fun unlink(__path : Char*) : Int
  fun write(__fd : Int, __buf : Void*, __count : SizeT) : SSizeT
end

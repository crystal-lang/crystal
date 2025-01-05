lib LibC
  struct Passwd
    pw_name : Char*
    pw_passwd : Char*
    pw_uid : UidT
    pw_gid : GidT
    pw_age : Char*
    pw_comment : Char*
    pw_gecos : Char*
    pw_dir : Char*
    pw_shell : Char*
  end

  fun getpwnam_r = __posix_getpwnam_r(login : Char*, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
  fun getpwuid_r = __posix_getpwuid_r(uid : UidT, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
end

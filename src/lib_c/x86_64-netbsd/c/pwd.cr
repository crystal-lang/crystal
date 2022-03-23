lib LibC
  struct Passwd
    pw_name : Char*
    pw_passwd : Char*
    pw_uid : UidT
    pw_gid : GidT
    pw_change : TimeT
    pw_class : Char*
    pw_gecos : Char*
    pw_dir : Char*
    pw_shell : Char*
    pw_expire : TimeT
  end

  fun getpwnam_r = __getpwnam_r50(login : Char*, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
  fun getpwuid_r = __getpwuid_r50(uid : UidT, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
end

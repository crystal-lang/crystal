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
    pw_fields : Int
  end

  fun getpwnam_r(login : Char*, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
  fun getpwuid_r(uid : UidT, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
end

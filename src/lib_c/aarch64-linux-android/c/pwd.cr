lib LibC
  struct Passwd
    pw_name : Char*
    pw_passwd : Char*
    pw_uid : UidT
    pw_gid : GidT
    pw_gecos : Char*
    pw_dir : Char*
    pw_shell : Char*
  end

  fun getpwnam_r(__name : Char*, __pwd : Passwd*, __buf : Char*, __n : SizeT, __result : Passwd**) : Int
  fun getpwuid_r(__uid : UidT, __pwd : Passwd*, __buf : Char*, __n : SizeT, __result : Passwd**) : Int
end

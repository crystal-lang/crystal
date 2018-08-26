lib LibC
  struct Passwd
    pw_name : Char*   # user name
    pw_passwd : Char* # encrypted password
    pw_uid : UidT     # user uid
    pw_gid : GidT     # user gid
    pw_gecos : Char*  # user information
    pw_dir : Char*    # home directory
    pw_shell : Char*  # shell program
  end

  fun getpwnam_r(login : Char*, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
  fun getpwuid_r(uid : UidT, pwstore : Passwd*, buf : Char*, bufsize : SizeT, result : Passwd**) : Int
end

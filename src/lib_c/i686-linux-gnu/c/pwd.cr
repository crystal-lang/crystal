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

  fun getpwnam(login : Char*) : Passwd*
  fun getpwuid(uid : UidT) : Passwd*
end

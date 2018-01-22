lib LibC
  struct Group
    gr_name : Char*   # group name
    gr_passwd : Char* # group password
    gr_gid : GidT     # group id
    gr_mem : Char**   # group members
  end

  fun getgrnam(login : Char*) : Group*
  fun getgrgid(uid : UidT) : Group*
end

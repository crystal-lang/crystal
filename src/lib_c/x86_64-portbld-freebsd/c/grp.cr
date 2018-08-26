lib LibC
  struct Group
    gr_name : Char*   # group name
    gr_passwd : Char* # group password
    gr_gid : GidT     # group id
    gr_mem : Char**   # group members
  end

  fun getgrnam_r(name : Char*, grp : Group*, buf : Char*, bufsize : SizeT, result : Group**) : Int
  fun getgrgid_r(gid : GidT, grp : Group*, buf : Char*, bufsize : SizeT, result : Group**) : Int
end

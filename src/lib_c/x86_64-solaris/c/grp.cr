lib LibC
  struct Group
    gr_name : Char*
    gr_passwd : Char*
    gr_gid : GidT
    gr_mem : Char**
  end

  fun getgrnam_r = __posix_getgrnam_r(name : Char*, grp : Group*, buf : Char*, bufsize : SizeT, result : Group**) : Int
  fun getgrgid_r = __posix_getgrgid_r(gid : GidT, grp : Group*, buf : Char*, bufsize : SizeT, result : Group**) : Int
end

lib LibC
  struct Group
    gr_name : Char*
    gr_passwd : Char*
    gr_gid : GidT
    gr_mem : Char**
  end

  {% if ANDROID_API >= 24 %}
    fun getgrnam_r(__name : Char*, __group : Group*, __buf : Char*, __n : SizeT, __result : Group**) : Int
    fun getgrgid_r(__gid : GidT, __group : Group*, __buf : Char*, __n : SizeT, __result : Group**) : Int
  {% end %}
end

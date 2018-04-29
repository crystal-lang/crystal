@[Link("dl")]
lib LibC
  RTLD_DEFAULT = Pointer(Void).new(0)

  struct DlInfo
    dli_fname : Char*
    dli_fbase : Void*
    dli_sname : Char*
    dli_saddr : Void*
  end

  fun dlclose(handle : Void*) : Int
  fun dlerror : Char*
  fun dlopen(filename : Char*, flag : Int) : Void*
  fun dlsym(handle : Void*, symbol : Char*) : Void*
  fun dladdr(addr : Void*, info : DlInfo*) : Int
end

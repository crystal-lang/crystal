@[Link("dl")]
lib LibC
  RTLD_LAZY    = 0x00001
  RTLD_NOW     = 0x00002
  RTLD_GLOBAL  = 0x00100
  RTLD_LOCAL   =       0
  RTLD_DEFAULT = Pointer(Void).new(0)

  struct DlInfo
    dli_fname : Char*
    dli_fbase : Void*
    dli_sname : Char*
    dli_saddr : Void*
  end

  fun dlclose(handle : Void*) : Int
  fun dlerror : Char*
  fun dlopen(file : Char*, mode : Int) : Void*
  fun dlsym(handle : Void*, name : Char*) : Void*
  fun dladdr(address : Void*, info : DlInfo*) : Int
end

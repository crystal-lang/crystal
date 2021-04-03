@[Link("dl")]
lib LibC
  RTLD_LAZY    = 0x1
  RTLD_NOW     = 0x2
  RTLD_GLOBAL  = 0x8
  RTLD_LOCAL   = 0x4
  RTLD_DEFAULT = Pointer(Void).new(-2)
  RTLD_NEXT    = Pointer(Void).new(-1)

  struct DlInfo
    dli_fname : Char*
    dli_fbase : Void*
    dli_sname : Char*
    dli_saddr : Void*
  end

  fun dlclose(handle : Void*) : Int
  fun dlerror : Char*
  fun dlopen(path : Char*, mode : Int) : Void*
  fun dlsym(handle : Void*, symbol : Char*) : Void*
  fun dladdr(x0 : Void*, x1 : DlInfo*) : Int
end

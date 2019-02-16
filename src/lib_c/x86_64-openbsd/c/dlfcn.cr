lib LibC
  RTLD_LAZY    =     1
  RTLD_NOW     =     2
  RTLD_GLOBAL  = 0x100
  RTLD_LOCAL   = 0x000
  RTLD_DEFAULT = Pointer(Void).new(-2)
  RTLD_NEXT    = Pointer(Void).new(-1)

  struct DlInfo
    dli_fname : Char*
    dli_fbase : Void*
    dli_sname : Char*
    dli_saddr : Void*
  end

  fun dlclose(x0 : Void*) : Int
  fun dlerror : Char*
  fun dlopen(x0 : Char*, x1 : Int) : Void*
  fun dlsym(x0 : Void*, x1 : Char*) : Void*
  fun dladdr(x0 : Void*, x1 : DlInfo*) : Int
end

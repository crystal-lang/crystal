@[Link(ldflags: "/system/lib64/libdl.so")]
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

  fun dlclose(__handle : Void*) : Int
  fun dlerror : Char*
  fun dlopen(__filename : Char*, __flag : Int) : Void*
  fun dlsym(__handle : Void*, __symbol : Char*) : Void*
  fun dladdr(__addr : Void*, __info : DlInfo*) : Int
end

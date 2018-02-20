lib LibC
  RTLD_LAZY   =     1
  RTLD_NOW    =     2
  RTLD_GLOBAL = 0x100
  RTLD_LOCAL  = 0x000
  RTLD_TRACE  = 0x200

  RTLD_NEXT    = Pointer(Void).new(-1) # Search subsequent objects.
  RTLD_DEFAULT = Pointer(Void).new(-2) # Use default search algorithm.
  RTLD_SELF    = Pointer(Void).new(-3) # Search the caller itself.

  struct DlInfo
    dli_fname : Char* # Pathname of shared object.
    dli_fbase : Void* # Base address of shared object.
    dli_sname : Char* # Name of nearest symbol.
    dli_saddr : Void* # Address of nearest symbol.
  end

  fun dlopen(path : Char*, mode : Int) : Void*
  fun dlclose(handle : Void*) : Int
  fun dlsym(handle : Void*, symbol : Char*) : Void*
  fun dlerror : Char*
  fun dladdr(addr : Void*, info : DlInfo*) : Int
end

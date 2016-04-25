@[Link("dl")]
lib LibDL
  LAZY   = 1
  GLOBAL = 8

  struct Info
    fname : LibC::Char*
    fbase : Void*
    sname : LibC::Char*
    saddr : Void*
  end

  fun dladdr(addr : Void*, info : Info*) : LibC::Int
  fun dlsym(handle : Void*, symbol : LibC::Char*) : Void*
  fun dlopen(path : LibC::Char*, mode : LibC::Int) : Void*

  ifdef darwin
    RTLD_NEXT      = Pointer(Void).new(-1)
    RTLD_DEFAULT   = Pointer(Void).new(-2)
    RTLD_SELF      = Pointer(Void).new(-3)
    RTLD_MAIN_ONLY = Pointer(Void).new(-5)
  else
    RTLD_NEXT    = Pointer(Void).new(-1)
    RTLD_DEFAULT = Pointer(Void).new(0)
  end
end

module DL
  def self.dlopen(path, mode = LibDL::LAZY | LibDL::GLOBAL) : Void*
    LibDL.dlopen(path, mode)
  end
end

@[Link("dl")]
lib LibDL
  LAZY = 1
  GLOBAL = 8

  struct Info
    fname : LibC::Char*
    fbase : Void*
    sname : LibC::Char*
    saddr : Void*
  end

  fun dladdr(addr : Void*, info : Info*) : LibC::Int
  fun dlopen(path : UInt8*, mode : LibC::Int) : Void*
end

module DL
  def self.dlopen(path, mode = LibDL::LAZY | LibDL::GLOBAL)
    LibDL.dlopen(path, mode)
  end
end

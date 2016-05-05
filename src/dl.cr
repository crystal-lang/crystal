require "c/dlfcn"

module DL
  def self.dlopen(path, mode = LibC::RTLD_LAZY | LibC::RTLD_GLOBAL) : Void*
    LibC.dlopen(path, mode)
  end
end

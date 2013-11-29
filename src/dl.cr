lib LibDL
  LAZY = 1
  GLOBAL = 8
  fun dlopen(path : Char*, mode : Int32) : Void*
end

module DL
  def self.dlopen(path, mode = LibDL::LAZY | LibDL::GLOBAL)
    LibDL.dlopen(path, mode)
  end
end

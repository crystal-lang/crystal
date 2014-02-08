require "./lib_tcl"

module Tcl
  def self.version
    LibTcl.get_version out major, out minor, out patch_level, out type
    "#{major}.#{minor} (patch level: #{patch_level})"
  end

  class Interpreter
    getter :lib_interp

    def initialize
      @lib_interp = LibTcl.create_interp
    end

    def create_obj(value : Int)
      IntObj.new(self, LibTcl.new_int_obj(value))
    end
  end

  class IntObj
    getter :interpreter
    getter :lib_obj

    def initialize(interpreter, lib_obj)
      @interpreter = interpreter
      @lib_obj = lib_obj
    end

    def value
      res = 0
      status = LibTcl.get_int_from_obj(interpreter.lib_interp, lib_obj, out res)
      raise "ERROR Tcl_GetIntFromObj" unless status == LibTcl::OK
      res
    end

    def value=(v : Int)
      LibTcl.set_int_obj(lib_obj, v)
      self
    end
  end
end

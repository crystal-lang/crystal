require "./lib_tcl"

module Tcl
  def self.version
    LibTcl.get_version out major, out minor, out patch_level, out type
    "#{major}.#{minor} (patch level: #{patch_level})"
  end

  def self.bool_to_i(value)
    value ? 1 : 0
  end

  def self.type_name(obj : Pointer(LibTcl::Obj))
    # String.new(obj.value.typePtr.value.name)
    obj.value.typePtr.address
  end

  class Interpreter
    getter :lib_interp

    def initialize
      @lib_interp = LibTcl.create_interp
    end

    def create_obj(value : Int)
      IntObj.new(self, LibTcl.new_int_obj(value))
    end

    def create_obj(value : Bool)
      BoolObj.new(self, LibTcl.new_boolean_obj(Tcl.bool_to_i(value)))
    end

    def create_obj(value : String)
      StringObj.new(self, LibTcl.new_string_obj(value, value.length))
    end

    def create_obj(value : Array(T))
      ListObj.new(self, LibTcl.new_list_obj(0, nil)).tap do |res|
        value.each do |v|
          res.push v.to_tcl(self)
        end
      end
    end

    def all_obj_types
      self.create_obj([] of Int32).tap do |res|
        status = LibTcl.append_all_obj_types(lib_interp, res.lib_obj)
        raise "ERROR Tcl_AppendAllObjTypes" unless status == LibTcl::OK
      end
    end
  end

  class Obj
    getter :interpreter
    getter :lib_obj

    def initialize(interpreter, lib_obj)
      @interpreter = interpreter
      @lib_obj = lib_obj
    end

    def to_tcl(interpreter)
      if @interpreter == interpreter
        self
      else
        raise "not supported"
      end
    end

    def tcl_type_name
      Tcl.type_name(lib_obj)
    end

    def self.concrete_new(interpreter, lib_obj)
      type_name = Tcl.type_name(lib_obj)
      type = if type_name == "int"
        IntObj
      else
        raise "concrete_new not implemented for #{type_name}"
      end

      type.new(interpreter, lib_obj)
    end

    def to_tcl_s
      res_length = 0
      # String.new(LibTcl.get_string_from_obj(interpreter.lib_interp, lib_obj, out res_length))
      String.new(LibTcl.get_string(lib_obj))
    end
  end

  class BoolObj < Obj
    def value
      res = 0
      status = LibTcl.get_boolean_from_obj(interpreter.lib_interp, lib_obj, out res)
      raise "ERROR Tcl_GetBooleanFromObj" unless status == LibTcl::OK
      res != 0
    end

    def value=(v : Bool)
      LibTcl.set_boolean_obj(lib_obj, Tcl.bool_to_i(v))
      self
    end
  end

  class IntObj < Obj
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

  class StringObj < Obj
    def value
      String.new(LibTcl.get_string(lib_obj))
    end

    def value=(v : String)
      LibTcl.set_string_obj(lib_obj, v, v.length)
      self
    end
  end

  class ListObj < Obj
    def length
      res = 0
      status = LibTcl.list_obj_length(interpreter.lib_interp, lib_obj, out res)
      raise "ERROR Tcl_ListObjLength" unless status == LibTcl::OK
      res
    end

    def at(index : Int)
      status = LibTcl.list_obj_index(interpreter.lib_interp, lib_obj, index, out res)
      raise "ERROR Tcl_ListObjIndex" unless status == LibTcl::OK
      Obj.concrete_new(interpreter, res)
    end

    def [](index : Int)
      at(index)
    end

    def size
      length
    end

    def push(value : Obj)
      status = LibTcl.list_obj_append_element(interpreter.lib_interp, lib_obj, value.lib_obj)
      raise "ERROR Tcl_ListObjLength" unless status == LibTcl::OK
    end
  end
end

struct Int
  def to_tcl(interpreter)
    interpreter.create_obj(self)
  end
end

struct Bool
  def to_tcl(interpreter)
    interpreter.create_obj(self)
  end
end

class String
  def to_tcl(interpreter)
    interpreter.create_obj(self)
  end
end

class Array(T)
  def to_tcl(interpreter)
    interpreter.create_obj(self)
  end
end

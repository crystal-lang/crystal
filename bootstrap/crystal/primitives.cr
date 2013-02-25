module Crystal
  class External < Def
    attr_accessor :real_name
    attr_accessor :varargs

    def mangled_name(obj_type)
      real_name
    end
  end
end

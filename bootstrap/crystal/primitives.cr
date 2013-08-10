module Crystal
  class External < Def
    property :real_name
    property :varargs

    def mangled_name(obj_type)
      real_name
    end
  end
end

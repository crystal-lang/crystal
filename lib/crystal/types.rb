module Crystal
  class Type
    def initialize(name)
      @name = name
    end

    Bool = Type.new "Bool"
    Int = Type.new "Int"
    Float = Type.new "Float"
  end
end
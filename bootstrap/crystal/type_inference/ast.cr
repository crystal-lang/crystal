require "../ast"

module Crystal
  class Def
    property :owner
    property :instances
  end

  class Arg
    def self.new_with_type(name, type)
      arg = new(name)
      arg.type = type
      arg
    end
  end
end

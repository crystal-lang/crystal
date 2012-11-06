module Crystal
  class Mutation
    attr_accessor :path
    attr_accessor :target

    def initialize(path, target)
      @path = path
      @target = target
    end

    def apply(types, force = false)
      type = types[path.index]
      var = nil
      path.path.each do |ivar|
        if type.is_a?(UnionType)
          type = type.types[ivar]
          var = nil
        else
          var = type.lookup_instance_var(ivar)
          type = var.type
        end
      end
      var.set_type nil if force
      var.type = target.is_a?(Type) ? target.clone : target.evaluate_types(types)
    end

    def ==(other)
      path == other.path && target == other.target
    end

    def with_index(index)
      Mutation.new(path.with_index(index), target)
    end

    def to_s
      "#{path} -> #{target}"
    end
  end
end

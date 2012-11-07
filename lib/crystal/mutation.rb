module Crystal
  class Mutation
    attr_accessor :path
    attr_accessor :target
    attr_accessor :force

    def initialize(path, target, force = false)
      @path = path
      @target = target
      @force = force
    end

    def apply(types)
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
      var.set_type nil if @force
      if target.is_a?(Array)
        var.type = Type.merge(target.map { |t| compute_target(t, types) })
      else
        var.type = compute_target(target, types)
      end
    end

    def compute_target(target, types, clone = true)
      target.is_a?(Type) ? (clone ? target.clone : target) : target.evaluate_types(types)
    end

    def evaluate_target(types)
      compute_target(target, types, false)
    end

    def ==(other)
      path == other.path && target == other.target && force == other.force
    end

    def with_index(index)
      Mutation.new(path.with_index(index), target)
    end

    def to_s
      "#{path} #{force ? '=>' : '->'} #{target}"
    end
  end
end

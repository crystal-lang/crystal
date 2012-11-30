require_relative 'type_inference.rb'

module Crystal
  def fix_empty_arrays(node, mod)
    node.accept FixEmptyArraysVisitor.new(mod)
  end

  class FixEmptyArraysVisitor < Visitor
    def initialize(mod)
      @mod = mod
      @fixed = {}
    end

    def visit_any(node)
      fix_node(node)
    end

    def end_visit_call(node)
      return if @fixed[node.target_def]
      @fixed[node.target_def] = true

      node.target_def.accept self if node.target_def
    end

    def fix_node(node)
      fix_type(node.type) if node.type
    end

    def fix_type(type)
      return if @fixed[type.object_id]
      @fixed[type.object_id] = true

      case type
      when ObjectType
        type.instance_vars.each do |name, ivar|
          fix_node(ivar)
        end
      when ArrayType
        unless type.element_type
          type.element_type = @mod.nil
        end
      when UnionType
        type.types.each do |type|
          fix_type(type)
        end
      end
    end
  end
end

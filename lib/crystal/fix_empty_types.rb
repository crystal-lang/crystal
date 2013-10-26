require_relative 'type_inference.rb'

module Crystal
  class Program
    def fix_empty_types(node)
      visitor = FixEmptyTypesVisitor.new(self)
      node.accept visitor
    end
  end

  class FixEmptyTypesVisitor < Visitor
    def initialize(mod)
      @mod = mod
      @fixed = {}
    end

    def visit_def(node)
      false
    end

    def visit_macro(node)
      false
    end

    def end_visit_call(node)
      return unless node.target_defs

      node.target_defs.each do |target_def|
        next if @fixed[target_def]
        @fixed[target_def] = true

        if target_def
          if !target_def.type && target_def.owner.allocated
            target_def.type = @mod.nil
          end
          target_def.accept_children self
        end
      end
    end

    def end_visit_ident(node)
      node.target_const.value.accept self if node.target_const
    end
  end
end

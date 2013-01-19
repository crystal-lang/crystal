require_relative 'type_inference.rb'

module Crystal
  def check_correctness(node)
    node.accept CheckVisitor.new
  end

  class Def
    attr_accessor :checked
  end

  class Dispatch
    attr_accessor :checked
  end

  class Var
    attr_accessor :checked
  end

  class CheckVisitor < Visitor
    def initialize
      @types = {}
    end

    def visit_def(node)
      false
    end

    def visit_macro(node)
      false
    end

    def end_visit_call(node)
      check(node, node.scope, "scope")
      if node.target_def && !node.target_def.checked
        node.target_def.checked = true

        node.target_def.accept_children self
        if node.target_def.is_a?(Dispatch)
          check(node)
        else
          check(node, node.target_def.owner, "target_def.owner")
        end
        check(node, node.target_def.type, "target_def.type")
      end
    end

    def end_visit_range_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_regexp_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_hash_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_array_literal(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_require(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_and(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_or(node)
      node.expanded.accept self if node.expanded
    end

    def end_visit_ident(node)
      node.target_const.value.accept self if node.target_const
    end

    def end_visit_var(node)
      node.checked = true
      check_var_dependencies(node)
    end

    def visit_case(node)
      node.expanded.accept self
      false
    end

    def visit_any(node)
      check(node)
      check_var_dependencies(node) unless node.is_a?(Var)
    end

    def check_var_dependencies(node)
      node.dependencies && node.dependencies.each do |dep|
        dep.accept self if dep.is_a?(Var) && !dep.checked
      end
    end

    def check(node, type = node.type, description = "type")
      saved_node, saved_type, saved_description = @types[type]
      if saved_type && saved_type.object_id != type.object_id
        msg =  "\nCorrectness check failed for #{type} vs. #{saved_type} :-(\n"
        msg << "First node: #{saved_node} (#{saved_node.class}##{saved_description}) at #{saved_node.filename}:#{saved_node.line_number}:#{saved_node.column_number}\n"
        msg << "Second node: #{node} (#{node.class}##{description}) at #{node.filename}:#{node.line_number}:#{node.column_number}"
        raise msg
      end
      @types[type] = [node, type, description]
    end
  end
end

require_relative 'ast.rb'

module Crystal
  def print_types(node)
    visitor = PrintTypesVisitor.new
    if node
      # Jump over the require "prelude" that's inserted by the compiler
      if node.is_a?(Expressions)
        node.expressions[1 .. -1].each do |exp|
          exp.accept visitor
        end
      else
        node.accept visitor
      end
    end
  end

  class PrintTypesVisitor < Visitor
    def initialize
      @vars = []
    end

    def visit_class_def(node)
      false
    end

    def visit_def(node)
      false
    end

    def visit_macro(node)
      false
    end

    def visit_assign(node)
      !node.target.is_a?(Ident)
    end

    def visit_var(node)
      if !node.name.start_with?('#') && !@vars.include?(node.name)
        puts "#{node.name} : #{node.type}"
        @vars << node.name
      end
    end
  end
end

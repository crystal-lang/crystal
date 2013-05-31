require_relative 'ast.rb'

module Crystal
  def print_types(node)
    visitor = PrintTypesVisitor.new
    if node
      # Jump over the require "prelude" that's inserted by the compiler
      node = node[1] if node.is_a?(Expressions)
      node.accept visitor
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

    def visit_var(node)
      if !node.name.start_with?('#') && !@vars.include?(node.name)
        puts "#{node.name} : #{node.type}"
        @vars << node.name
      end
    end
  end
end

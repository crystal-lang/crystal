require_relative 'ast.rb'

module Crystal
  def print_types(node)
    visitor = PrintTypesVisitor.new
    node.accept visitor if node
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
      unless @vars.include? node.name
        puts "#{node.name} : #{node.type}"
        @vars << node.name
      end
    end
  end
end

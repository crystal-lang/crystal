require "ast"
require "set"

module Crystal
  def print_types(node)
    visitor = PrintTypesVisitor.new
    # Jump over the require "prelude" that's inserted by the compiler
    if node.is_a?(Expressions)
      node.expressions[1 .. -1].each do |exp|
        exp.accept visitor
      end
    else
      node.accept visitor
    end
  end

  class PrintTypesVisitor < Visitor
    def initialize
      @vars = Set(String).new
    end

    def visit(node)
      true
    end

    def visit(node : ClassDef)
      false
    end

    def visit(node : Def)
      false
    end

    def visit(node : FunDef)
      false
    end

    def visit(node : Macro)
      false
    end

    def visit(node : Assign)
      !node.target.is_a?(Ident)
    end

    def visit(node : Var)
      output_name node
    end

    def visit(node : Global)
      output_name node
    end

    # def visit(node : DeclareVar)
    #   output_name node
    # end

    def output_name(node)
      if !node.name.starts_with?('#') && !@vars.includes?(node.name)
        puts "#{node.name} : #{node.type}"
        @vars.add node.name
      end
    end
  end
end

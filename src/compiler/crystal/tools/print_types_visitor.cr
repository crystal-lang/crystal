require "set"
require "../syntax/ast"

module Crystal
  def self.print_types(node)
    node.accept PrintTypesVisitor.new
  end

  class PrintTypesVisitor < Visitor
    @vars : Set(String)

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
      !node.target.is_a?(Path)
    end

    def visit(node : Var)
      output_name node
    end

    def visit(node : Global)
      output_name node
    end

    def visit(node : TypeDeclaration)
      var = node.var
      if var.is_a?(Var)
        output_name var
      end
    end

    def visit(node : UninitializedVar)
      var = node.var
      if var.is_a?(Var)
        output_name var
      end
    end

    def output_name(node)
      if !node.name.starts_with?('#') && !@vars.includes?(node.name)
        puts "#{node.name} : #{node.type?}"
        @vars.add node.name
      end
    end
  end
end

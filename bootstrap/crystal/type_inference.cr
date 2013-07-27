require "program"
require "visitor"
require "ast"
require "type_inference/ast_node"

module Crystal
  def infer_type(node)
    mod = Crystal::Program.new
    if node
      node.accept TypeVisitor.new(mod)
    end
    mod
  end

  class TypeVisitor < Visitor
    attr_reader :mod

    def initialize(mod, vars = {} of String => Var)
      @mod = mod
      @vars = vars
    end

    def visit(node : ASTNode)
    end

    def visit(node : BoolLiteral)
      node.type = mod.bool
    end

    def visit(node : IntLiteral)
      node.type = mod.int
    end

    def visit(node : LongLiteral)
      node.type = mod.long
    end

    def visit(node : FloatLiteral)
      node.type = mod.float
    end

    def visit(node : DoubleLiteral)
      node.type = mod.double
    end

    def visit(node : CharLiteral)
      node.type = mod.char
    end

    def visit(node : SymbolLiteral)
      node.type = mod.symbol
    end

    def visit(node : Var)
      var = lookup_var node.name
      node.bind_to var
    end

    def end_visit(node : Expressions)
      node.bind_to node.last unless node.empty?
    end

    def visit(node : Assign)
      type_assign node.target, node.value, node
    end

    def type_assign(target, value, node)
      value.accept self

      if target.is_a?(Var)
        var = lookup_var target.name
        target.bind_to var

        node.bind_to value
        var.bind_to node
      end

      false
    end

    def lookup_var(name)
      if @vars.has_key?(name)
        var = @vars[name]
      else
        var = Var.new name
        @vars[name] = var
      end
      var
    end
  end
end
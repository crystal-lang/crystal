module Crystal
  class ASTNode
    attr_accessor :type
  end

  def type(node)
    node.accept TypeVisitor.new
  end

  class TypeVisitor < Visitor
    def initialize
      @scope = [{}]
      @defs = {}
    end

    def visit_bool(node)
      node.type = Type::Bool
    end

    def visit_int(node)
      node.type = Type::Int
    end

    def visit_float(node)
      node.type = Type::Float
    end

    def visit_assign(node)
      node.value.accept self
      node.type = node.target.type = node.value.type

      define_var node.target

      false
    end

    def visit_var(node)
      node.type = lookup_var node.name
    end

    def end_visit_expressions(node)
      node.type = node.expressions.last.type
    end

    def visit_def(node)
      @defs[node.name] = node
      false
    end

    def visit_call(node)
      node.args.each do |arg|
        arg.accept self
      end

      a_def = @defs[node.name].clone

      with_new_scope do
        a_def.args.each_with_index do |arg, i|
          a_def.args[i].type = node.args[i].type
          define_var a_def.args[i]
        end
        a_def.body.accept self
      end

      node.type = a_def.body.type

      false
    end

    def define_var(var)
      @scope.last[var.name] = var.type
    end

    def lookup_var(name)
      @scope.last[name]
    end

    def with_new_scope
      @scope.push({})
      yield
      @scope.pop
    end
  end
end
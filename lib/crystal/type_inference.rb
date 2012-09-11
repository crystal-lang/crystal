module Crystal
  class ASTNode
    attr_accessor :type
  end

  class Def
    attr_accessor :instances

    def add_instance(a_def)
      @instances ||= []
      @instances << a_def
    end
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

      untyped_def = @defs[node.name]
      typed_def = untyped_def.clone

      with_new_scope do
        typed_def.args.each_with_index do |arg, i|
          typed_def.args[i].type = node.args[i].type
          define_var typed_def.args[i]
        end
        typed_def.body.accept self
      end

      node.type = typed_def.body.type

      untyped_def.add_instance typed_def

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
module Crystal
  class ASTNode
    attr_accessor :type
  end

  class Call
    attr_accessor :target_def
  end

  class Def
    attr_accessor :owner
    attr_accessor :instances

    def add_instance(a_def)
      @instances ||= []
      @instances << a_def
    end
  end

  def type(node)
    node.accept TypeVisitor.new(node)
  end

  class TypeVisitor < Visitor
    def initialize(root)
      @root = root
      @scopes = [{vars: {}}]
      @defs = {}
      @classes = {}
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
      class_def = node.parent.parent
      if class_def
        @classes[class_def.name][:defs][node.name] = node
      else
        @defs[node.name] = node
      end
      false
    end

    def visit_call(node)
      if node.obj
        node.obj.accept self
        scope = @classes[node.obj.type.name][:defs]
      else
        scope = @defs
      end

      untyped_def = scope[node.name]

      unless untyped_def
        error = node.has_parenthesis ? "undefined method" : "undefined local variable or method"
        compile_error "#{error} '#{node.name}'", node.line_number, node.name_column_number, node.name.length
      end

      if node.args.length != untyped_def.args.length
        compile_error "wrong number of arguments for '#{node.name}' (#{node.args.length} for #{untyped_def.args.length})", node.line_number, node.name_column_number, node.name.length
      end

      node.args.each do |arg|
        arg.accept self
      end

      node.target_def = typed_def = untyped_def.clone

      typed_def.owner = node.obj.type if node.obj

      with_new_scope(node.line_number, untyped_def) do
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

    def visit_class_def(node)
      @classes[node.name] ||= {defs: {}}
    end

    def define_var(var)
      @scopes.last[:vars][var.name] = var.type
    end

    def lookup_var(name)
      @scopes.last[:vars][name]
    end

    def with_new_scope(line, obj)
      scope[:line] = line
      @scopes.push({vars: {}, obj: obj})
      yield
      @scopes.pop
    end

    def scope
      @scopes.last
    end

    def compile_error(message, line, column, length)
      str = "Error: #{message}"
      str << " in '#{scope[:obj].name}'" if scope[:obj]
      str << "\n\n"
      str << @root.source_code.lines.at(line - 1).chomp
      str << "\n"
      str << (' ' * (column - 1))
      str << '^'
      str << ('~' * (length - 1))
      str << "\n"
      str << "\n"
      @scopes.reverse_each do |scope|
        str << "in line #{scope[:line] || line}"
        str << ": '#{scope[:obj].name}'\n" if scope[:obj]
      end
      raise Crystal::Exception.new(str.strip)
    end
  end
end
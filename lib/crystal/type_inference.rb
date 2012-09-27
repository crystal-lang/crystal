module Crystal
  class ASTNode
    attr_accessor :type
    attr_accessor :dependants

    def add_dependant(target)
      @dependants ||= []
      @dependants << target
      target.type = type
    end

    def type=(type)
      return if type.nil?
      if @type.nil?
        @type = type
      else
        @type = [@type, type].flatten.uniq
        @type = @type.first if @type.length == 1
      end
      @dependants && @dependants.each do |dependant|
        dependant.type = type
      end
    end
  end

  class Call
    attr_accessor :target_def
  end

  class Def
    attr_accessor :owner
    attr_accessor :instances

    def add_instance(a_def)
      @instances ||= {}
      @instances[a_def.args.map(&:type)] = a_def
    end

    def lookup_instance(arg_types)
      @instances && @instances[arg_types]
    end
  end

  def infer_type(node)
    mod = Crystal::Module.new
    node.accept TypeVisitor.new(mod, node)
    mod
  end

  class TypeVisitor < Visitor
    attr_accessor :mod

    def initialize(mod, root, vars = {})
      @mod = mod
      @root = root
      @vars = vars
    end

    def visit_bool(node)
      node.type = mod.bool
    end

    def visit_int(node)
      node.type = mod.int
    end

    def visit_float(node)
      node.type = mod.float
    end

    def visit_char(node)
      node.type = mod.char
    end

    def visit_def(node)
      # class_def = node.parent.parent
      # if class_def
      #   mod.types[class_def.name].defs[node.name] = node
      # else
        mod.defs[node.name] = node
      # end
      false
    end

    def visit_var(node)
      var = lookup_var node.name
      var.add_dependant node
    end

    def end_visit_assign(node)
      node.value.add_dependant node

      var = lookup_var node.target.name
      node.add_dependant var
    end

    def end_visit_expressions(node)
      node.last.add_dependant node if node.last
    end

    def end_visit_while(node)
      node.type = mod.void
    end

    def end_visit_if(node)
      node.then.add_dependant node
      node.else.add_dependant node if node.else
    end

    def end_visit_call(node)
      untyped_def = mod.defs[node.name]

      typed_def = untyped_def.lookup_instance(node.args.map &:type)
      unless typed_def
        typed_def = untyped_def.clone

        args = {}
        typed_def.args.each_with_index do |arg, index|
          args[arg.name] = Var.new(arg.name)
          node.args[index].add_dependant args[arg.name]
          args[arg.name].add_dependant typed_def.args[index]
        end

        untyped_def.add_instance typed_def
        typed_def.body.accept TypeVisitor.new(@mod, typed_def.body, args)
      end

      node.target_def = typed_def
      typed_def.body.add_dependant node
    end

    def lookup_var(name)
      var = @vars[name]
      unless var
        var = Var.new name
        @vars[name] = var
      end
      var
    end

    def compile_error_on_node(message, node)
      compile_error message, node.line_number, node.column_number, node.name.length
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
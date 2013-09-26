require "program"
require "visitor"
require "ast"
require "type_inference/*"

module Crystal
  class Program
    def infer_type(node)
      node.accept TypeVisitor.new(self)
      node
    end
  end

  class TypeVisitor < Visitor
    getter :mod

    def initialize(@mod, @vars = {} of String => Var, @scope = nil, @parent = nil, @call = nil, @owner = nil, @untyped_def = nil, @typed_def = nil, @arg_types = nil, @free_vars = nil, @yield_vars = nil)
      @types = [@mod] of Type
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : BoolLiteral)
      node.type = mod.bool
    end

    def visit(node : NumberLiteral)
      node.type = case node.kind
                  when :i8
                    mod.int8
                  when :i16
                    mod.int16
                  when :i32
                    mod.int32
                  when :i64
                    mod.int64
                  when :u8
                    mod.int8
                  when :u16
                    mod.int16
                  when :u32
                    mod.int32
                  when :u64
                    mod.int64
                  when :f32
                    mod.float32
                  when :f64
                    mod.float64
                  end
    end

    def visit(node : CharLiteral)
      node.type = mod.char
    end

    def visit(node : SymbolLiteral)
      node.type = mod.symbol
    end

    def visit(node : StringLiteral)
      node.type = mod.string
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

    def visit(node : Def)
      # if receiver = node.receiver
        # # TODO: hack
        # if node.receiver.is_a?(Var) && node.receiver.name == 'self'
        #   target_type = current_type.metaclass
        # else
        #   target_type = lookup_ident_type(node.receiver).metaclass
        # end
      # else
        target_type = current_type
      # end

      target_type.add_def node

      false
    end

    def visit(node : Call)
      prepare_call(node)

      if obj = node.obj
        obj.accept self
      end

      node.args.each do |arg|
        arg.accept self
      end
      node.recalculate

      false
    end

    def prepare_call(node)
      node.mod = mod

      # if node.global
      #   node.scope = @mod
      # else
        node.scope = @scope #|| (@types.last ? @types.last.metaclass : nil)
      # end
      node.parent_visitor = self
    end

    def visit(node : ClassDef)
      superclass = if node_superclass = node.superclass
                     lookup_ident_type node_superclass
                   else
                     mod.reference
                   end

      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_ident_type node.name
      end

      type = scope.types[name]?
      if type
        # node.raise "#{name} is not a class" unless type.is_a?(ClassType)
        # if node.superclass && type.superclass != superclass
        #   node.raise "superclass mismatch for class #{type.name} (#{superclass.name} for #{type.superclass.name})"
        # end
      else
        needs_force_add_subclass = true
        # if node.type_vars
        #   type = GenericClassType.new scope, name, superclass, node.type_vars, false
        # else
          unless superclass.is_a?(InheritableClass)
            raise "Bug: node_superclass can't be nil here" unless node_superclass
            node_superclass.raise "#{superclass} is not a class"
          end
          type = NonGenericClassType.new scope, name, superclass, false
        # end
        # type.abstract = node.abstract
        scope.types[name] = type
      end

      @types.push type
      node.body.accept self
      @types.pop

      type.force_add_subclass if needs_force_add_subclass

      false
    end

    def visit(node : LibDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
      else
        type = LibType.new current_type, node.name, node.libname
        # current_type.types[node.name] = type
      end
      @types.push type
    end

    def end_visit_lib_def(node)
      @types.pop
    end

    def lookup_var(name)
      @vars.fetch_or_assign(name) { Var.new name }
    end

    def lookup_ident_type(node : Ident)
      # if @free_vars && !node.global && type = @free_vars[[node.names.first]]
      #   if node.names.length == 1
      #     target_type = type
      #   else
      #     target_type = type.lookup_type(node.names[1 .. -1])
      #   end
      # elsif node.global
      if node.global
        target_type = mod.lookup_type node.names
      else
        target_type = (@scope || @types.last).lookup_type node.names
      end

      unless target_type
        node.raise "uninitialized constant #{node}"
      end

      target_type
    end

    def lookup_ident_type(node)
      raise "lookup_ident_type not implemented for #{node}"
    end

    def current_type
      @types.last
    end
  end
end

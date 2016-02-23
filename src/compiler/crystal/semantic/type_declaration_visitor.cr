require "./base_type_visitor"

module Crystal
  class Program
    def visit_type_declarations(node)
      node.accept TypeDeclarationVisitor.new(self)
      node
    end
  end

  # In this pass we check type declarations like:
  # - @x : Int32
  # - @@x : Int32
  # - $x : Int32
  #
  # In this way we declare their type before the "main" code.
  #
  # This allows to put "main" code before these declarations,
  # so order matters less in the end.
  #
  # In the future these will be mandatory and after this pass
  # we'll have a complete definition of the type hierarchy and
  # their instance/class variables types.
  class TypeDeclarationVisitor < BaseTypeVisitor
    def initialize(mod)
      super(mod)

      @inside_block = 0
      @process_types = 0
    end

    def processing_types
      @process_types += 1
      value = yield
      @process_types -= 1
      value
    end

    def visit(node : Path)
      @process_types > 0 ? super : false
    end

    def visit(node : Generic)
      @process_types > 0 ? super : false
    end

    def visit(node : Fun)
      @process_types > 0 ? super : false
    end

    def visit(node : Union)
      @process_types > 0 ? super : false
    end

    def visit(node : Metaclass)
      @process_types > 0 ? super : false
    end

    def visit(node : ClassDef)
      check_outside_block_or_exp node, "declare class"

      pushing_type(node.resolved_type) do
        node.runtime_initializers.try &.each &.accept self
        node.body.accept self
      end

      false
    end

    def visit(node : ModuleDef)
      check_outside_block_or_exp node, "declare module"

      pushing_type(node.resolved_type) do
        node.body.accept self
      end

      false
    end

    def visit(node : Alias)
      check_outside_block_or_exp node, "declare alias"

      false
    end

    def visit(node : Include)
      check_outside_block_or_exp node, "include"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : Extend)
      check_outside_block_or_exp node, "extend"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : LibDef)
      check_outside_block_or_exp node, "declare lib"

      false
    end

    def visit(node : FunDef)
      false
    end

    def visit(node : TypeDeclaration)
      case var = node.var
      when Var
        node.raise "declaring the type of a local variable is not yet supported"
      when InstanceVar
        type = current_type
        case type
        when NonGenericClassType
          processing_types do
            node.declared_type.accept self
          end
          var_type = check_declare_var_type node
          type.declare_instance_var(var.name, var_type.virtual_type)
        when GenericClassType
          type.declare_instance_var(var.name, node.declared_type)
        when GenericClassInstanceType
          # OK
        else
          node.raise "can only declare instance variables of a non-generic class, not a #{type.type_desc} (#{type})"
        end
      when ClassVar
        class_var = lookup_class_var(var, bind_to_nil_if_non_existent: false)

        processing_types do
          node.declared_type.accept self
        end
        var_type = check_declare_var_type node

        class_var.freeze_type = var_type.virtual_type
      when Global
        if @untyped_def
          node.raise "declaring the type of a global variable must be done at the class level"
        end

        global_var = mod.global_vars[var.name]?
        unless global_var
          global_var = Global.new(var.name)
          mod.global_vars[var.name] = global_var
        end

        processing_types do
          node.declared_type.accept self
        end

        var_type = check_declare_var_type node

        global_var.freeze_type = var_type.virtual_type
      end

      node.type = @mod.nil

      false
    end

    def visit(node : Def)
      check_outside_block_or_exp node, "declare def"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : Macro)
      check_outside_block_or_exp node, "declare macro"

      false
    end

    def visit(node : Call)
      if node.global
        node.scope = @mod
      else
        node.scope = current_type.metaclass
      end

      if expand_macro(node, raise_on_missing_const: false)
        false
      else
        true
      end
    end

    def visit(node : UninitializedVar)
      false
    end

    def visit(node : Assign)
      false
    end

    def visit(node : FunLiteral)
      false
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : IsA)
      false
    end

    def visit(node : Cast)
      false
    end

    def visit(node : InstanceSizeOf)
      false
    end

    def visit(node : SizeOf)
      false
    end

    def visit(node : TypeOf)
      false
    end

    def visit(node : PointerOf)
      false
    end

    def visit(node : ArrayLiteral)
      false
    end

    def visit(node : HashLiteral)
      false
    end

    def inside_block?
      @inside_block > 0
    end
  end
end

require "./base_type_visitor"
require "./type_guess_visitor"

module Crystal
  class Program
    def visit_type_declarations(node)
      processor = TypeDeclarationProcessor.new(self)
      processor.process(node)
    end
  end

  # In this pass we check type declarations like:
  #
  #     @x : Int32
  #     @@x : Int32
  #     $x : Int32
  #
  # In this way we declare their type before the "main" code.
  #
  # This allows to put "main" code before these declarations,
  # so order matters less in the end.
  class TypeDeclarationVisitor < BaseTypeVisitor
    alias TypeDeclarationWithLocation = TypeDeclarationProcessor::TypeDeclarationWithLocation

    getter globals
    getter class_vars
    getter instance_vars

    def initialize(mod,
                   @instance_vars : Hash(Type, Hash(String, TypeDeclarationWithLocation)))
      super(mod)

      # The type of global variables. The last one wins.
      @globals = {} of String => Type

      # The type of class variables. The last one wins.
      # This is type => variables.
      @class_vars = {} of ClassVarContainer => Hash(String, Type)
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

    def visit(node : EnumDef)
      check_outside_block_or_exp node, "declare enum"

      pushing_type(node.resolved_type) do
        node.members.each &.accept self
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
        declare_instance_var(node, var)
      when ClassVar
        declare_class_var(node, var)
      when Global
        declare_global_var(node, var)
      end

      false
    end

    def declare_instance_var(node, var)
      unless current_type.allows_instance_vars?
        node.raise "can't declare instance variables in #{current_type}"
      end

      case owner = current_type
      when NonGenericClassType
        declare_instance_var_on_non_generic(owner, node, var)
        return
      when GenericClassType
        declare_instance_var_on_generic(owner, node, var)
        return
      when GenericModuleType
        declare_instance_var_on_generic(owner, node, var)
        return
      when GenericClassInstanceType
        # OK
        return
      when Program, FileModule
        # Error, continue
      when NonGenericModuleType
        declare_instance_var_on_non_generic(owner, node, var)
        return
      end

      node.raise "can only declare instance variables of a non-generic class, not a #{owner.type_desc} (#{owner})"
    end

    def declare_instance_var_on_non_generic(owner, node, var)
      # For non-generic types we can solve the type now
      var_type = lookup_type(node.declared_type)
      var_type = check_declare_var_type(node, var_type)
      owner_vars = @instance_vars[owner] ||= {} of String => TypeDeclarationWithLocation
      type_decl = TypeDeclarationWithLocation.new(var_type.virtual_type, node.location.not_nil!)
      owner_vars[var.name] = type_decl
    end

    def declare_instance_var_on_generic(owner, node, var)
      # For generic types we must delay the type resolution
      owner_vars = @instance_vars[owner] ||= {} of String => TypeDeclarationWithLocation
      type_decl = TypeDeclarationWithLocation.new(node.declared_type, node.location.not_nil!)
      owner_vars[var.name] = type_decl
    end

    def declare_class_var(node, var)
      owner = class_var_owner(node)
      var_type = lookup_type(node.declared_type).virtual_type
      var_type = check_declare_var_type(node, var_type)
      owner_vars = @class_vars[owner] ||= {} of String => Type
      owner_vars[var.name] = var_type
    end

    def declare_global_var(node, var)
      var_type = lookup_type(node.declared_type).virtual_type
      var_type = check_declare_var_type(node, var_type)
      @globals[var.name] = var_type
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

    def lookup_type(node)
      TypeLookup.lookup(current_type, node, allow_typeof: false)
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

    def visit(node : IsA)
      false
    end

    def visit(node : Cast)
      false
    end

    def visit(node : NilableCast)
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

    def visit(node : Path)
      false
    end

    def visit(node : Generic)
      false
    end

    def visit(node : Fun)
      false
    end

    def visit(node : Union)
      false
    end

    def visit(node : Metaclass)
      false
    end

    def visit(node : Self)
      false
    end

    def visit(node : TypeOf)
      false
    end

    def inside_block?
      false
    end
  end
end

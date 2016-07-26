require "./base_type_visitor"
require "./type_guess_visitor"

module Crystal
  class Program
    def visit_type_declarations(node)
      processor = TypeDeclarationProcessor.new(self)
      processor.process(node)
      {node, processor}
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
  #
  # This visitor also processes the following:
  #
  # - C struct/union fields
  # - fun declarations
  #
  # This is because we need to type the fields, arguments and
  # return types and now we can because TopLevelVisitor declared
  # all types that could be referenced.
  class TypeDeclarationVisitor < BaseTypeVisitor
    alias TypeDeclarationWithLocation = TypeDeclarationProcessor::TypeDeclarationWithLocation

    getter globals
    getter class_vars
    getter instance_vars

    def initialize(mod,
                   @instance_vars : Hash(Type, Hash(String, TypeDeclarationWithLocation)))
      super(mod)

      # The type of global variables. The last one wins.
      @globals = {} of String => TypeDeclarationWithLocation

      # The type of class variables. The last one wins.
      # This is type => variables.
      @class_vars = {} of ClassVarContainer => Hash(String, TypeDeclarationWithLocation)
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

      if @in_c_struct_or_union
        include_c_struct(node)
        return false
      end

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def include_c_struct(node)
      type = current_type.as(NonGenericClassType)

      included_type = lookup_type(node.name)
      unless included_type.is_a?(NonGenericClassType) && included_type.extern? && !included_type.extern_union?
        node.name.raise "can only include C struct, not #{included_type.type_desc}"
      end

      included_type.instance_vars.each_value do |var|
        field_name = var.name[1..-1]
        if type.lookup_instance_var?(var.name)
          node.raise "struct #{included_type} has a field named '#{field_name}', which #{type} already defines"
        end
        declare_c_struct_or_union_field type, field_name, var
      end
    end

    def visit(node : Extend)
      check_outside_block_or_exp node, "extend"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : LibDef)
      check_outside_block_or_exp node, "declare lib"

      pushing_type(node.resolved_type) do
        @in_lib = true
        @attributes = nil
        node.body.accept self
        @in_lib = false
      end

      false
    end

    def visit(node : CStructOrUnionDef)
      pushing_type(node.resolved_type) do
        @in_c_struct_or_union = true
        node.body.accept self
        @in_c_struct_or_union = false
      end

      false
    end

    def visit(node : ExternalVar)
      attributes = check_valid_attributes node, ValidExternalVarAttributes, "external var"

      var_type = lookup_type(node.type_spec)
      var_type = check_allowed_in_lib node.type_spec, var_type
      thread_local = Attribute.any?(attributes, "ThreadLocal")

      type = current_type.as(LibType)
      type.add_var node.name, var_type, (node.real_name || node.name), thread_local

      false
    end

    def visit(node : FunDef)
      check_outside_block_or_exp node, "declare fun"

      if node.body && !current_type.is_a?(Program)
        node.raise "can only declare fun at lib or global scope"
      end

      call_convention = check_call_convention_attributes node
      attributes = check_valid_attributes node, ValidFunDefAttributes, "fun"
      node.doc ||= attributes_doc()

      args = node.args.map do |arg|
        restriction = arg.restriction.not_nil!
        arg_type = lookup_type(restriction)
        arg_type = check_allowed_in_lib(restriction, arg_type)
        if arg_type.remove_typedef.void?
          restriction.raise "can't use Void as argument type"
        end
        Arg.new(arg.name, type: arg_type).at(arg.location)
      end

      node_return_type = node.return_type
      if node_return_type
        return_type = lookup_type(node_return_type)
        return_type = check_allowed_in_lib(node_return_type, return_type) unless return_type.nil_type?
        return_type = @program.nil if return_type.void?
      else
        return_type = @program.nil
      end

      external = External.new(node.name, args, node.body, node.real_name).at(node)
      external.set_type(return_type)
      external.varargs = node.varargs?
      external.fun_def = node
      external.call_convention = call_convention
      external.doc = node.doc
      check_ditto external
      node.external = external

      process_def_attributes(external, attributes)

      begin
        old_external = current_type.add_def external
      rescue ex : Crystal::Exception
        node.raise ex.message
      end

      if old_external.is_a?(External)
        old_external.dead = true
      end

      if current_type.is_a?(Program)
        key = DefInstanceKey.new external.object_id, external.args.map(&.type), nil, nil
        current_type.add_def_instance key, external
      end

      node.type = @program.nil

      false
    end

    def visit(node : TypeDeclaration)
      case var = node.var
      when Var
        if @in_c_struct_or_union
          declare_c_struct_or_union_field(node)
          return false
        end

        node.raise "declaring the type of a local variable is not yet supported"
      when InstanceVar
        declare_instance_var(node, var)
      when ClassVar
        declare_class_var(node, var, false)
      when Global
        declare_global_var(node, var, false)
      end

      false
    end

    def declare_c_struct_or_union_field(node)
      type = current_type.as(NonGenericClassType)

      field_type = lookup_type(node.declared_type)
      field_type = check_allowed_in_lib node.declared_type, field_type
      if field_type.remove_typedef.void?
        node.declared_type.raise "can't use Void as a #{type.type_desc} field type"
      end

      field_name = node.var.as(Var).name
      var_name = '@' + field_name

      if type.lookup_instance_var?(var_name)
        node.raise "#{type.type_desc} #{type} already defines a field named '#{field_name}'"
      end
      ivar = MetaTypeVar.new(var_name, field_type)
      ivar.owner = type
      declare_c_struct_or_union_field type, field_name, ivar
    end

    def declare_c_struct_or_union_field(type, field_name, var)
      type.instance_vars[var.name] = var
      type.add_def Def.new("#{field_name}=", [Arg.new("value")], Primitive.new(type.extern_union? ? :union_set : :struct_set))
      type.add_def Def.new(field_name, body: InstanceVar.new(var.name))
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
      var_type = check_declare_var_type(node, var_type, "an instance variable")
      owner_vars = @instance_vars[owner] ||= {} of String => TypeDeclarationWithLocation
      type_decl = TypeDeclarationWithLocation.new(var_type.virtual_type, node.location.not_nil!, false)
      owner_vars[var.name] = type_decl
    end

    def declare_instance_var_on_generic(owner, node, var)
      # For generic types we must delay the type resolution
      owner_vars = @instance_vars[owner] ||= {} of String => TypeDeclarationWithLocation
      type_decl = TypeDeclarationWithLocation.new(node.declared_type, node.location.not_nil!, false)
      owner_vars[var.name] = type_decl
    end

    def declare_class_var(node, var, uninitialized)
      owner = class_var_owner(node)
      var_type = lookup_type(node.declared_type)
      var_type = check_declare_var_type(node, var_type, "a class variable")
      owner_vars = @class_vars[owner] ||= {} of String => TypeDeclarationWithLocation
      owner_vars[var.name] = TypeDeclarationWithLocation.new(var_type.virtual_type, node.location.not_nil!, uninitialized)
    end

    def declare_global_var(node, var, uninitialized)
      var_type = lookup_type(node.declared_type)
      var_type = check_declare_var_type(node, var_type, "a global variable")
      @globals[var.name] = TypeDeclarationWithLocation.new(var_type.virtual_type, node.location.not_nil!, uninitialized)
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
      node.scope = node.global? ? @program : current_type.metaclass

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
      var = node.var
      case var
      when ClassVar
        declare_class_var(node, var, true)
      when Global
        declare_global_var(node, var, true)
      end
      false
    end

    def visit(node : Assign)
      false
    end

    def visit(node : ProcLiteral)
      node.def.body.accept self
      false
    end

    def visit(node : IsA)
      node.obj.accept self
      false
    end

    def visit(node : Cast)
      node.obj.accept self
      false
    end

    def visit(node : NilableCast)
      node.obj.accept self
      false
    end

    def visit(node : Path)
      false
    end

    def visit(node : Generic)
      false
    end

    def visit(node : ProcNotation)
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

    def inside_block?
      false
    end
  end
end

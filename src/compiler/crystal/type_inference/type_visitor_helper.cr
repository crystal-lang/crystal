require "../ast"

module Crystal
  module TypeVisitorHelper
    def process_class_def(node : ClassDef)
      superclass = if node_superclass = node.superclass
                     lookup_path_type node_superclass
                   elsif node.struct
                    mod.value
                   else
                     mod.reference
                   end

      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_path_type node.name, true
      end

      type = scope.types[name]?

      if !type && superclass
        if (!!node.struct) != (!!superclass.struct?)
          node.raise "can't make #{node.struct ? "struct" : "class"} '#{node.name}' inherit #{superclass.type_desc} '#{superclass.to_s}'"
        end
      end

      if type
        unless type.is_a?(ClassType)
          node.raise "#{name} is not a #{node.struct ? "struct" : "class"}, it's a #{type.type_desc}"
        end

        if (!!node.struct) != (!!type.struct?)
          node.raise "#{name} is not a #{node.struct ? "struct" : "class"}, it's a #{type.type_desc}"
        end

        if node.superclass && type.superclass != superclass
          node.raise "superclass mismatch for class #{type} (#{superclass} for #{type.superclass})"
        end
      else
        unless superclass.is_a?(NonGenericClassType)
          node_superclass.not_nil!.raise "#{superclass} is not a class, it's a #{superclass.type_desc}"
        end

        needs_force_add_subclass = true
        if type_vars = node.type_vars
          type = GenericClassType.new @mod, scope, name, superclass, type_vars, false
        else
          type = NonGenericClassType.new @mod, scope, name, superclass, false
        end
        type.abstract = node.abstract
        type.struct = node.struct
        scope.types[name] = type
      end

      @types.push type
      yield
      @types.pop

      if needs_force_add_subclass
        raise "Bug" unless type.is_a?(InheritableClass)
        type.force_add_subclass
      end

      false
    end

    def process_module_def(node : ModuleDef)
      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_path_type node.name, true
      end

      type = scope.types[name]?
      if type
        unless type.module?
          node.raise "#{name} is not a module, it's a #{type.type_desc}"
        end
      else
        if type_vars = node.type_vars
          type = GenericModuleType.new @mod, scope, name, type_vars
        else
          type = NonGenericModuleType.new @mod, scope, name
        end
        scope.types[name] = type
      end

      @types.push type
      yield
      @types.pop

      false
    end

    def process_macro(node : Macro)
      if receiver = node.receiver
        # TODO: hack
        if receiver.is_a?(Var) && receiver.name == "self"
          target_type = current_type.metaclass
        else
          target_type = lookup_path_type(receiver).metaclass
        end
      else
        target_type = current_type
      end

      target_type.add_macro node

      false
    end

    def process_def(node : Def)
      if receiver = node.receiver
        # TODO: hack
        if receiver.is_a?(Var) && receiver.name == "self"
          target_type = current_type.metaclass
        else
          target_type = lookup_path_type(receiver).metaclass
        end
      else
        target_type = current_type
      end

      target_type.add_def node
    end

    def process_alias(node : Alias)
      alias_type = AliasType.new(@mod, current_type, node.name)
      current_type.types[node.name] = alias_type
      node.value.accept self
      alias_type.aliased_type = node.value.type.instance_type
    end

    def process_include(node : Include)
      node_name = node.name

      if node_name.is_a?(NewGenericClass)
        type = lookup_path_type(node_name.name)
      else
        type = lookup_path_type(node_name)
      end

      unless type.module?
        node.name.raise "#{node.name} is not a module, it's a #{type.type_desc}"
      end

      current_type = current_type()

      if node_name.is_a?(NewGenericClass)
        unless type.is_a?(GenericModuleType)
          node_name.raise "#{type} is not a generic module"
        end

        if type.type_vars.length != node_name.type_vars.length
          node_name.raise "wrong number of type vars for #{type} (#{node_name.type_vars.length} for #{type.type_vars.length})"
        end

        type_vars_types = node_name.type_vars.map do |type_var|
          if type_var.is_a?(SelfType)
            current_type
          else
            unless type_var.is_a?(Path)
              type_var.raise "only simple names are supported for now, not #{type_var}"
            end

            type_var_name = type_var.names[0]
            if current_type.is_a?(GenericType) && current_type.type_vars.includes?(type_var_name)
              type_var_name
            else
              lookup_path_type(type_var)
            end
          end
        end

        mapping = Hash.zip(type.type_vars, type_vars_types)
        current_type.include IncludedGenericModule.new(@mod, type, current_type, mapping)
      else
        if type.is_a?(GenericModuleType)
          if current_type.is_a?(GenericType)
            current_type_type_vars_length = current_type.type_vars.length
            if current_type_type_vars_length != type.type_vars.length
              node_name.raise "#{type} wrong number of type vars for #{type} (#{current_type_type_vars_length} for #{current_type.type_vars.length})"
            end

            mapping = Hash.zip(type.type_vars, current_type.type_vars)
            current_type.include IncludedGenericModule.new(@mod, type, current_type, mapping)
          else
            node_name.raise "#{type} is a generic module"
          end
        else
          current_type.include type
        end
      end
    end

    def process_lib_def(node : LibDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
      else
        type = LibType.new @mod, current_type, node.name, node.libname
        current_type.types[node.name] = type
      end
      @types.push type
      yield
      @types.pop
    end

    def process_type_def(node : TypeDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        typed_def_type = check_primitive_like node.type_spec
        current_type.types[node.name] = TypeDefType.new @mod, current_type, node.name, typed_def_type
      end
    end

    def process_struct_def(node : StructDef)
      process_struct_or_union_def node, CStructType
    end

    def process_union_def(node : UnionDef)
      process_struct_or_union_def node, CUnionType
    end

    def process_struct_or_union_def(node, klass)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        fields = node.fields.map do |field|
          field_type = check_primitive_like field.restriction.not_nil!
          Var.new(field.name, field_type)
        end
        current_type.types[node.name] = klass.new @mod, current_type, node.name, fields
      end
    end

    def process_enum_def(node : EnumDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        counter = 0
        node.constants.each do |constant|
          if default_value = constant.default_value
            counter = (default_value as NumberLiteral).value.to_i
          else
            constant.default_value = NumberLiteral.new(counter, :i32)
          end
          counter += 1
        end
        current_type.types[node.name] = CEnumType.new(@mod, current_type, node.name, node.constants)
      end
    end

    def process_external_var(node : ExternalVar)
      node.type_spec.accept self

      var_type = check_primitive_like node.type_spec

      type = current_type as LibType
      type.add_var node.name, var_type, (node.real_name || node.name)
    end

    def process_fun_def(node : FunDef)
      if node.body && !current_type.is_a?(Program)
        node.raise "can only declare fun at lib or global scope"
      end

      args = node.args.map do |arg|
        restriction = arg.restriction.not_nil!
        restriction.accept self

        arg_type = check_primitive_like(restriction.not_nil!)

        fun_arg = Arg.new_with_type(arg.name, arg_type)
        fun_arg.location = arg.location
        fun_arg
      end

      node_return_type = node.return_type
      if node_return_type
        node_return_type.accept self
        return_type = check_primitive_like(node_return_type)
      else
        return_type = @mod.void
      end

      external = External.for_fun(node.name, node.real_name, args, return_type, node.varargs, node.body, node)
      if node_body = node.body
        vars = {} of String => Var
        args.each do |arg|
          var = Var.new(arg.name, arg.type)
          var.bind_to var
          vars[arg.name] = var
        end
        external.set_type(nil)

        visitor = TypeVisitor.new(@mod, vars, @mod, self, nil, nil, external, external, args.map(&.type))
        begin
          node_body.accept visitor
        rescue ex : Crystal::Exception
          node.raise ex.message, ex
        end

        inferred_return_type = @mod.type_merge([node_body.type?, external.type?])

        if return_type && return_type != @mod.void && inferred_return_type != return_type
          node.raise "expected fun to return #{return_type} but it returned #{inferred_return_type}"
        end

        external.set_type(return_type)

        if node.name == Crystal::RAISE_NAME
          external.raises = true
        end
      elsif node.name == Crystal::MAIN_NAME
        external.raises = true
      end

      begin
        old_external = current_type.add_def external
      rescue ex
        node.raise ex.message
      end

      if old_external.is_a?(External)
        old_external.dead = true
      end

      if node.body
        current_type.add_def_instance external.object_id, external.args.map(&.type), nil, external
      end

      node.type = @mod.nil
    end

    def process_ident_union(node : Union)
      node.type = @mod.type_merge(node.types.map &.type.instance_type)
    end

    def process_hierarchy(node : Hierarchy)
      node.type = node.name.type.instance_type.hierarchy_type.metaclass
    end

    def process_metaclass_node(node : MetaclassNode)
      node.type = node.name.type.hierarchy_type.metaclass
    end

    def process_new_generic_class(node : NewGenericClass)
      return if node.type?

      instance_type = node.name.type.instance_type
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.type_vars.length != node.type_vars.length
        node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{instance_type.type_vars.length})"
      end
      node.instance_type = instance_type
      node.type_vars.each &.add_observer(node)
      node.update
    end

    def process_allocate(node)
      instance_type = scope.instance_type

      if instance_type.is_a?(GenericClassType)
        node.raise "can't create instance of generic class #{instance_type} without specifying its type vars"
      end

      if instance_type.is_a?(ClassType) && instance_type.abstract
        node.raise "can't instantiate abstract class #{instance_type}"
      end

      instance_type
    end

    def lookup_path_type(node : Path, create_modules_if_missing = false)
      target_type = resolve_ident(node, create_modules_if_missing)
      if target_type.is_a?(Type)
        target_type.remove_alias_if_simple
      else
        node.raise "#{node} must be a type here, not #{target_type}"
      end
    end

    def lookup_path_type(node)
      raise "lookup_path_type not implemented for #{node}"
    end

    def resolve_ident(node : Path, create_modules_if_missing = false)
      free_vars = @free_vars
      if free_vars && !node.global && (type = free_vars[node.names.first]?)
        if node.names.length == 1
          target_type = type.not_nil!
        else
          target_type = type.not_nil!.lookup_type(node.names[1 .. -1])
        end
      else
        base_lookup = node.global ? mod : (@scope || @types.last)
        target_type = base_lookup.lookup_type node

        if !target_type && create_modules_if_missing
          next_type = base_lookup
          node.names.each do |name|
            next_type = base_lookup.lookup_type([name])
            if next_type
              if next_type.is_a?(ASTNode)
                node.raise "execpted #{name} to be a type"
              end
            else
              next_type = NonGenericModuleType.new(@mod, base_lookup, name)
              base_lookup.types[name] = next_type
            end
            base_lookup = next_type
          end
          target_type = next_type
        end
      end

      unless target_type
        node.raise "uninitialized constant #{node}"
      end

      target_type
    end

    def check_primitive_like(node)
      type = node.type.instance_type
      unless type.primitive_like?
        msg = String.build do |msg|
          msg << "only primitive types, pointers, structs, unions and enums are allowed in lib declarations"
          msg << " (did you mean Int32?)" if type == @mod.int
          msg << " (did you mean Float32?)" if type == @mod.float
        end
        node.raise msg
      end

      if type.c_enum?
        type = @mod.int32
      elsif type.is_a?(TypeDefType) && type.typedef.fun?
        type = type.typedef
      end

      type
    end

    def current_type
      @types.last
    end
  end
end

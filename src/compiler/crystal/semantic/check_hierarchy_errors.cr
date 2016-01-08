class Crystal::Program
  def check_hierarchy_errors
    RecursiveStructChecker.new(self).run
    AbstractDefChecker.new(self).run
  end

  class RecursiveStructChecker
    def initialize(@program)
      @all_checked = Set(Type).new
    end

    def run
      check_types(@program)
    end

    def check_types(type)
      type.types.each_value do |type|
        check_single(type)
      end
    end

    def check_single(type)
      return if @all_checked.includes?(type)
      @all_checked << type

      if struct?(type)
        target = type
        checked = Set(Type).new
        path = [] of Var
        check_recursive_instance_var_container(target, type, checked, path)
      end

      check_types(type)
      check_generic_instances(type)
    end

    def check_generic_instances(type)
      if type.struct? && type.is_a?(GenericType)
        type.generic_types.each_value do |instance|
          check_single(instance)
        end
      end
    end

    def check_recursive(target, type, checked, path)
      if target == type
        msg = "recursive struct #{target} detected: #{path_to_s(path)}"
        location = target.locations.first?
        if location
          raise TypeException.new(msg, location)
        else
          raise TypeException.new(msg)
        end
      end

      return if checked.includes?(type)

      case type
      when InstanceVarContainer
        if struct?(type)
          check_recursive_instance_var_container(target, type, checked, path)
        end
      when UnionType
        type.union_types.each do |union_type|
          check_recursive(target, union_type, checked, path)
        end
      end
    end

    def check_recursive_instance_var_container(target, type, checked, path)
      checked.add type
      (type as InstanceVarContainer).instance_vars.each_value do |var|
        var_type = var.type?
        next unless var_type

        path.push var
        check_recursive(target, var_type, checked, path)
        path.pop
      end
      checked.delete type
    end

    def path_to_s(path)
      path.join(" -> ") { |var| "`#{var.name} : #{var.type}`" }
    end

    def struct?(type)
      type.struct? && type.is_a?(InstanceVarContainer) && !type.is_a?(PrimitiveType) && !type.is_a?(FunInstanceType) && !type.is_a?(GenericClassType) && !type.abstract
    end
  end

  class AbstractDefChecker
    def initialize(@program)
      @all_checked = Set(Type).new
    end

    def run
      check_types(@program)
    end

    def check_types(type)
      type.types.each_value do |type|
        check_single(type)
      end
    end

    def check_single(type)
      return if @all_checked.includes?(type)
      @all_checked << type

      if type.abstract || type.module?
        type.defs.try &.each_value do |defs_with_metadata|
          defs_with_metadata.each do |def_with_metadata|
            a_def = def_with_metadata.def
            if a_def.abstract
              # TODO: for now we skip methods with splats and default arguments
              next if a_def.splat_index || a_def.args.any? &.default_value

              check_implemented_in_subtypes(type, a_def)
            end
          end
        end
      end

      check_types(type)
    end

    def check_implemented_in_subtypes(type, method)
      check_implemented_in_subtypes(type, type, method)
    end

    def check_implemented_in_subtypes(base, type, method)
      # TODO: check generic modules
      subtypes = case type
                 when NonGenericModuleType
                   type.raw_including_types
                 else
                   type.subclasses
                 end

      subtypes.try &.each do |subtype|
        next if implements_with_parents?(subtype, method, base)

        if subtype.abstract || subtype.module?
          check_implemented_in_subtypes(base, subtype, method)
        else
          method.raise "abstract `def #{Call.def_full_name(base, method)}` must be implemented by #{subtype}"
        end
      end
    end

    def implements_with_parents?(type : Type, method : Def, base)
      return true if implements?(type, method, base)

      type.parents.try &.each do |parent|
        break if parent == base
        return true if implements?(parent, method, base)
      end

      return false
    end

    def implements?(type : Type, method : Def, base)
      type.defs.try &.each_value do |defs_with_metadata|
        defs_with_metadata.each do |def_with_metadata|
          a_def = def_with_metadata.def
          return true if implements?(type, a_def, base, method)
        end
      end
      false
    end

    def implements?(t1 : Type, m1 : Def, t2 : Type, m2 : Def)
      return false if m1.abstract
      return false unless m1.name == m2.name
      return false unless m1.yields == m2.yields

      # TODO: for now we consider that if there's a splat, the method is implemented
      return true if m1.splat_index

      return false if m1.args.size < m2.args.size

      m2.args.zip(m1.args) do |a2, a1|
        r1 = a1.restriction
        r2 = a2.restriction
        if r2 && r1 && r1 != r2
          # Check if a1.restriction is contravariant with a2.restriction
          begin
            rt1 = TypeLookup.lookup(t1, r1)
            rt2 = TypeLookup.lookup(t2, r2)
            return false unless rt2.covariant?(rt1)
          rescue Crystal::TypeException
            # Ignore if we can't find a type (assume the method is implemented)
            next
          end
        end
      end

      # If the method has more arguments, but default values for them, it implements it
      if m1.args.size > m2.args.size
        return false unless m1.args[m2.args.size].default_value
      end

      true
    end
  end
end

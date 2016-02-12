module Crystal
  class Program
    def check_recursive_structs
      RecursiveStructChecker.new(self).run
    end
  end

  # Checks that there are no recursive structs in the program.
  #
  # An example of a recursive struct is:
  #
  # ```
  # struct Test
  #   def initialize(@test)
  #   end
  # end
  #
  # Test.new(Test.new(nil))
  # ```
  #
  # Because the type of `Test.@test` would be: `Test | Nil`.
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
      (type as InstanceVarContainer).all_instance_vars.each_value do |var|
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
end

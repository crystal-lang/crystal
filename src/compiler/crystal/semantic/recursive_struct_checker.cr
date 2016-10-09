# Checks that there are no recursive structs in the program.
#
# An example of a recursive struct is:
#
# ```
# struct Test
#   def initialize(@test : Test | Nil)
#   end
# end
#
# Test.new(Test.new(nil))
# ```
#
# Because the type of `Test.@test` would be: `Test | Nil`.
class Crystal::RecursiveStructChecker
  @program : Program
  @all_checked : Set(Type)

  def initialize(@program)
    @all_checked = Set(Type).new
  end

  def run
    check_types(@program)
  end

  def check_types(type)
    type.types?.try &.each_value do |type|
      check_single(type)
    end
  end

  def check_single(type)
    return if @all_checked.includes?(type)
    @all_checked << type

    if struct?(type)
      target = type
      checked = Set(Type).new
      path = [] of Var | Type
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
      msg = <<-MSG
        recursive struct #{target} detected: #{path_to_s(path)}

        The struct #{target} has, either directly or indirectly,
        an instance variable whose type is, eventually, this same
        struct. This makes it impossible to represent the struct
        in memory, because the size of this instance variable depends
        on the size of this struct, which depends on the size of
        this instance variable, causing an infinite cycle.

        You should probably be using classes here, as classes
        instance variables are always behind a pointer, which makes
        it possible to always compute a size for them.
        MSG
      location = target.locations.try &.first?
      if location
        raise TypeException.new(msg, location)
      else
        raise TypeException.new(msg)
      end
    end

    return if checked.includes?(type)

    if type.is_a?(VirtualType)
      if type.struct?
        path.push type
        type.subtypes.each do |subtype|
          path.push subtype
          check_recursive(target, subtype, checked, path)
          path.pop
        end
        path.pop
      end
    end

    if type.is_a?(NonGenericModuleType)
      path.push type
      # Check if the module is composed, recursively, of the target struct
      type.raw_including_types.try &.each do |module_type|
        path.push module_type
        check_recursive(target, module_type, checked, path)
        path.pop
      end
      path.pop
    end

    if type.is_a?(InstanceVarContainer)
      if struct?(type)
        check_recursive_instance_var_container(target, type, checked, path)
      end
    end

    if type.is_a?(UnionType)
      type.union_types.each do |union_type|
        check_recursive(target, union_type, checked, path)
      end
    end
  end

  def check_recursive_instance_var_container(target, type, checked, path)
    checked.add type
    type.all_instance_vars.each_value do |var|
      var_type = var.type?
      next unless var_type

      path.push var
      check_recursive(target, var_type, checked, path)
      path.pop
    end
    checked.delete type
  end

  def path_to_s(path)
    path.join(" -> ") do |var_or_type|
      case var_or_type
      when Var
        "`#{var_or_type.name} : #{var_or_type.type.devirtualize}`"
      else
        "`#{var_or_type.devirtualize}`"
      end
    end
  end

  def struct?(type)
    type.struct? && type.is_a?(InstanceVarContainer) && !type.is_a?(PrimitiveType) && !type.is_a?(ProcInstanceType) && !type.is_a?(GenericClassType) && !type.abstract?
  end
end

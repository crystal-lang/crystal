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

    if type.is_a?(AliasType) && !type.simple?
      target = type
      checked = Set(Type).new
      path = [] of Var | Type
      check_recursive(target, type.aliased_type, checked, path)
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
      if target.is_a?(AliasType)
        alias_message = " (recursive aliases are structs)"
      end

      msg = <<-MSG
        recursive struct #{target} detected#{alias_message}:

          #{path_to_s(path)}

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
        push(path, type) do
          type.subtypes.each do |subtype|
            push(path, subtype) do
              check_recursive(target, subtype, checked, path)
            end
          end
        end
      end
    end

    if type.is_a?(NonGenericModuleType) || type.is_a?(GenericModuleInstanceType)
      push(path, type) do
        # Check if the module is composed, recursively, of the target struct
        type.raw_including_types.try &.each do |module_type|
          push(path, module_type) do
            check_recursive(target, module_type, checked, path)
          end
        end
      end
    end

    if type.is_a?(InstanceVarContainer)
      if struct?(type)
        check_recursive_instance_var_container(target, type, checked, path)
      end
    end

    if type.is_a?(UnionType)
      push(path, type) do
        type.union_types.each do |union_type|
          push(path, union_type) do
            check_recursive(target, union_type, checked, path)
          end
        end
      end
    end

    if type.is_a?(TupleInstanceType)
      push(path, type) do
        type.tuple_types.each do |tuple_type|
          push(path, tuple_type) do
            check_recursive(target, tuple_type, checked, path)
          end
        end
      end
    end

    if type.is_a?(NamedTupleInstanceType)
      push(path, type) do
        type.entries.each do |entry|
          push(path, entry.type) do
            check_recursive(target, entry.type, checked, path)
          end
        end
      end
    end
  end

  def check_recursive_instance_var_container(target, type, checked, path)
    checked.add type
    type.all_instance_vars.each_value do |var|
      var_type = var.type?
      next unless var_type

      push(path, var) do
        check_recursive(target, var_type, checked, path)
      end
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
    type.struct? && type.is_a?(InstanceVarContainer) && !type.is_a?(PrimitiveType) && !type.is_a?(ProcInstanceType) && !type.abstract?
  end

  def push(path, type)
    if path.last? == type
      yield
    else
      path.push type
      yield
      path.pop
    end
  end
end

# Checks that abstract methods are implemented.
#
# We traverse all abstract types in the program (abstract classes/structs
# and modules) and for each abstract method we find, we traverse the implementors
# (subtypes and including types) and see if they implement that method.
#
# An abstract method is either implemented if the type restriction (if any) matches,
# of if there's no type restriction. For example:
#
# ```
# abstract class Foo
#   abstract def foo(x : Int32)
# end
#
# class Bar < Foo
#   # OK
#   def foo(x : Int32); end
# end
#
# class Baz < Foo
#   # OK too, because it's more general
#   def foo(x); end
# end
# ```
#
# TODO: the check currently ignores methods that involve splats.
class Crystal::AbstractDefChecker
  def initialize(@program : Program)
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

    if type.abstract? || type.module?
      type.defs.try &.each_value do |defs_with_metadata|
        defs_with_metadata.each do |def_with_metadata|
          a_def = def_with_metadata.def
          if a_def.abstract?
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
      next if implements_with_ancestors?(subtype, method, base)

      # Union doesn't need a hash, dup, to_s, etc., methods because it's special
      next if subtype == @program.union

      if subtype.abstract? || subtype.module?
        check_implemented_in_subtypes(base, subtype, method)
      else
        method.raise "abstract `def #{Call.def_full_name(base, method)}` must be implemented by #{subtype}"
      end
    end
  end

  def implements_with_ancestors?(type : Type, method : Def, base)
    return true if implements?(type, method, base)

    type.ancestors.any? do |ancestor|
      implements?(ancestor, method, base)
    end
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
    return false if m1.abstract?
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
          rt1 = t1.lookup_type(r1)
          rt2 = t2.lookup_type(r2)
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

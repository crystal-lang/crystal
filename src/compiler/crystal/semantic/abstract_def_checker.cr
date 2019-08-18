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
    subtypes = case type
               when NonGenericModuleType
                 type.raw_including_types
               when GenericModuleType
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

  def implements_with_ancestors?(type : Type, method : Def, base : Type)
    return true if implements?(type, type, method, base)

    type.ancestors.any? do |ancestor|
      implements?(type, ancestor, method, base)
    end
  end

  # Returns `true` if `ancestor_type` implements `method` of `base` when computing
  # that information to check whether `target_type` implements `method` of `base`.
  def implements?(target_type : Type, ancestor_type : Type, method : Def, base : Type)
    ancestor_type.defs.try &.each_value do |defs_with_metadata|
      defs_with_metadata.each do |def_with_metadata|
        a_def = def_with_metadata.def

        if implements?(target_type, ancestor_type, a_def, base, method)
          check_return_type(target_type, ancestor_type, a_def, base, method)
          return true
        end
      end
    end
    false
  end

  # Returns `true` if the method `t1#m1` implements `t2#m2` when computing
  # that to check whether `target_type` implements `t2#m2`
  # (`t1` is an ancestor of `target_type`).
  def implements?(target_type : Type, t1 : Type, m1 : Def, t2 : Type, m2 : Def)
    return false if m1.abstract?
    return false unless m1.name == m2.name
    return false unless m1.yields == m2.yields

    # TODO: for now we consider that if there's a splat, the method is implemented
    return true if m1.splat_index

    return false if m1.args.size < m2.args.size

    # If the base type is a generic type, we find the generic instantiation of
    # t1 for it. This will have a mapping of type vars to types, for example
    # T will be Int32 in something like `class Bar < Foo(Int32)` with `Foo(T)`.
    # Then we replace all `T` in the base method with `Int32`, and just then
    # we check if they match.
    if t2.is_a?(GenericType)
      # We must find the generic instantiation starting from the target type,
      # not from t1, because maybe t1 doesn't reach the generic base type.
      generic_base = find_base_generic_instantiation(target_type, t2)
      m2 = replace_method_arg_paths_with_type_vars(t2, m2, generic_base)
    end

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

  # Checks that the return type of `type#method` matches that of `base_type#base_method`
  # when computing that information for `target_type` (`type` is an ancestor of `target_type`).
  def check_return_type(target_type : Type, type : Type, method : Def, base_type : Type, base_method : Def)
    base_return_type_node = base_method.return_type
    return unless base_return_type_node

    original_base_return_type = base_type.lookup_type?(base_return_type_node)
    unless original_base_return_type
      report_warning(base_return_type_node, "can't resolve return type #{base_return_type_node}\n#{this_warning_will_become_an_error}")
      return
    end

    # If the base type is a generic type, we find the generic instantiation of
    # t1 for it. This will have a mapping of type vars to types, for example
    # T will be Int32 in something like `class Bar < Foo(Int32)` with `Foo(T)`.
    # Then we replace all `T` in the base method return type with `Int32`,
    # and just then we check if they match.
    if base_type.is_a?(GenericType)
      generic_base = find_base_generic_instantiation(target_type, base_type)
      replacer = ReplacePathWithTypeVar.new(base_type, generic_base)
      base_return_type_node = base_return_type_node.clone
      base_return_type_node.accept(replacer)
    end

    base_return_type = base_type.lookup_type?(base_return_type_node)
    unless base_return_type
      report_warning(base_return_type_node, "can't resolve return type #{base_return_type_node}\n#{this_warning_will_become_an_error}")
      return
    end

    return_type_node = method.return_type
    unless return_type_node
      report_warning(method, "this method overrides #{Call.def_full_name(base_type, base_method)} which has an explicit return type of #{original_base_return_type}.\n#{@program.colorize("Please add an explicit return type (#{base_return_type} or a subtype of it) to this method as well.").yellow.bold}\n\n#{this_warning_will_become_an_error}")
      return
    end

    return_type = type.lookup_type?(return_type_node)
    unless return_type
      report_warning(return_type_node, "can't resolve return type #{return_type_node}\n#{this_warning_will_become_an_error}")
      return
    end

    unless return_type.implements?(base_return_type)
      report_warning(return_type_node, "this method must return #{base_return_type}, which is the return type of the overridden method #{Call.def_full_name(base_type, base_method)}, or a subtype of it, not #{return_type}\n#{this_warning_will_become_an_error}")
      return
    end
  end

  def replace_method_arg_paths_with_type_vars(base_type : Type, method : Def, generic_type : GenericInstanceType)
    replacer = ReplacePathWithTypeVar.new(base_type, generic_type)

    method = method.clone
    method.args.each do |arg|
      arg.restriction.try &.accept(replacer)
    end
    method
  end

  def find_base_generic_instantiation(type : Type, base_type : GenericType)
    type.ancestors.find do |t|
      t.is_a?(GenericInstanceType) && t.generic_type == base_type
    end.as(GenericInstanceType)
  end

  private def this_warning_will_become_an_error
    @program.colorize("The above warning will become an error in a future Crystal version.").yellow.bold
  end

  private def report_warning(node, message)
    return unless @program.warnings.all?
    return if @program.ignore_warning_due_to_location?(node.location)

    @program.warning_failures << node.warning(message)
  end

  class ReplacePathWithTypeVar < Visitor
    def initialize(@base_type : GenericType, @generic_type : GenericInstanceType)
    end

    def visit(node : Path)
      if !node.global? && node.names.size == 1
        # Check if it matches any of the generic type vars
        name = node.names.first

        type_var = @generic_type.type_vars[name]?
        if type_var.is_a?(Var)
          # Check that it's actually a type parameter on the base type
          if @base_type.lookup_type?(node).is_a?(TypeParameter)
            node.type = type_var.type
          end
        end
      end

      false
    end

    def visit(node : ASTNode)
      true
    end
  end
end

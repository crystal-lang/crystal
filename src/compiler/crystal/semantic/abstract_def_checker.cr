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
class Crystal::AbstractDefChecker
  def initialize(@program : Program)
    @all_checked = Set(Type).new
  end

  def run
    check_types(@program)
    @program.file_modules.each_value do |file_module|
      check_types(file_module)
    end
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
            free_vars = free_var_nodes(a_def)
            check_implemented_in_subtypes(type, a_def, free_vars)
          end
        end
      end
    end

    check_types(type)
  end

  def check_implemented_in_subtypes(type, method, free_vars)
    check_implemented_in_subtypes(type, type, method, free_vars)
  end

  def check_implemented_in_subtypes(base, type, method, free_vars)
    subtypes = case type
               when NonGenericModuleType
                 type.raw_including_types
               when GenericModuleType
                 type.raw_including_types
               else
                 type.subclasses
               end

    subtypes.try &.each do |subtype|
      next if implements_with_ancestors?(subtype, method, base, free_vars)

      # Union doesn't need a hash, dup, to_s, etc., methods because it's special
      next if subtype == @program.union

      if subtype.abstract? || subtype.module?
        check_implemented_in_subtypes(base, subtype, method, free_vars)
      else
        msg = "abstract `def #{Call.def_full_name(base, method)}` must be implemented by #{subtype}"
        if location = subtype.locations.try &.first?
          raise TypeException.new(msg, location)
        else
          raise TypeException.new(msg)
        end
      end
    end
  end

  def implements_with_ancestors?(type : Type, method : Def, base : Type, free_vars)
    return true if implements?(type, type, method, base, free_vars)

    type.ancestors.any? do |ancestor|
      if implements?(type, ancestor, method, base, free_vars)
        # Check that the implementation does not come from a supertype of `base`
        if ancestor.is_a?(GenericInstanceType)
          ancestor = ancestor.generic_type.as(Type)
        end
        !base.implements?(ancestor)
      else
        false
      end
    end
  end

  # Returns `true` if `ancestor_type` implements `method` of `base` when computing
  # that information to check whether `target_type` implements `method` of `base`.
  def implements?(target_type : Type, ancestor_type : Type, method : Def, base : Type, method_free_vars)
    implemented = false
    found_param_match = false
    ancestor_type.defs.try &.each_value do |defs_with_metadata|
      defs_with_metadata.each do |def_with_metadata|
        a_def = def_with_metadata.def
        def_free_vars = free_var_nodes(a_def)

        if implements?(target_type, ancestor_type, a_def, def_free_vars, base, method, method_free_vars)
          unless implemented
            check_return_type(target_type, ancestor_type, a_def, base, method)
            implemented = true
          end

          unless found_param_match || target_type.abstract? || target_type.module?
            check_positional_param_names(a_def, base, method)
            found_param_match = true if same_parameters?(a_def, method)
          end
        end
      end
    end
    implemented
  end

  # Returns `true` if the method `t1#m1` implements `t2#m2` when computing
  # that to check whether `target_type` implements `t2#m2`
  # (`t1` is an ancestor of `target_type`).
  def implements?(target_type : Type, t1 : Type, m1 : Def, free_vars1, t2 : Type, m2 : Def, free_vars2)
    return false if m1.abstract?
    return false unless m1.name == m2.name
    return false unless m1.block_arity == m2.block_arity

    m1_args, m1_kargs = def_arg_ranges(m1)
    m2_args, m2_kargs = def_arg_ranges(m2)

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

    # First check positional arguments
    # The following algorithm walk through the arguments in the abstract
    # method and the implementation at the same time, until a splat argument is found
    # or the end of the positional argument list is reached in both lists.
    # The table below resumes the allowed cases (OK) and rejected (x) for each combination
    # of the argument in the implementation (a1) and the abstract def (a2).
    # `an = Dn` represents an argument with a default value. `-` represents that
    # no more arguments are available to compare.
    # Allowed cases are then verified that they have compatible default value
    # and type restrictions.
    #
    #         |  a2  | a2 = D2 | *a2 |  -  |
    # a1      |  OK  |   x     | x   |  x  |
    # a1 = D1 |  OK  |   OK    | OK  |  OK |
    # *a1     |  OK  |   x     | OK  |  OK |
    # -       |  x   |   x     | x   |  OK |
    i1 = i2 = 0
    loop do
      a1 = i1 <= m1_args ? m1.args[i1] : nil
      a2 = i2 <= m2_args ? m2.args[i2] : nil

      case
      when !a1
        # No more arguments in the implementation
        return false unless !a2
      when i1 == m1.splat_index
        # The argument in the implementation is a splat
        return false if a2 && a2.default_value
      when !a1.default_value
        # The argument in the implementation doesn't have a default value
        return false if !a2 || a2.default_value || i2 == m2.splat_index
      end

      if a1 && a2
        return false unless check_arg(t1, a1, free_vars1, t2, a2, free_vars2)
      end

      # Move next, unless we're on the splat already or at the end of the arguments
      done = true
      unless i1 == m1.splat_index || a1 == nil
        i1 += 1
        done = false
      end
      unless i2 == m2.splat_index || a2 == nil
        i2 += 1
        done = false
      end
      break if done
    end

    # Index keyword arguments
    kargs =
      m1_kargs.to_h do |i|
        a1 = m1.args[i]
        {a1.name, a1}
      end

    # Check double splat
    if m2_double_splat = m2.double_splat
      if m1_double_splat = m1.double_splat
        return false unless check_arg(t1, m1_double_splat, free_vars1, t2, m2_double_splat, free_vars2)
      else
        return false
      end
    end

    # Check keyword arguments
    # They must either exist in the implementation or match with the double splat
    m2_kargs.each do |i|
      a2 = m2.args[i]
      if a1 = kargs.delete(a2.name) || m1.double_splat
        return false unless check_arg(t1, a1, free_vars1, t2, a2, free_vars2)
      else
        return false
      end
    end

    # Check remaining keyword arguments
    # They must have a default value and match the double splat in the abstract (if it exists)
    kargs.each_value do |a1|
      return false unless a1.default_value
      if m2_double_splat = m2.double_splat
        return false unless check_arg(t1, a1, free_vars1, t2, m2_double_splat, free_vars2)
      end
    end

    true
  end

  private def def_arg_ranges(method : Def)
    if splat = method.splat_index
      if method.args[splat].name.size == 0
        {splat - 1, (splat + 1...method.args.size)}
      else
        {splat, (splat + 1...method.args.size)}
      end
    else
      {method.args.size - 1, (0...0)}
    end
  end

  def check_arg(t1 : Type, a1 : Arg, free_vars1, t2 : Type, a2 : Arg, free_vars2)
    if a2.default_value
      return false unless a1.default_value == a2.default_value
    end

    r1 = a1.restriction
    r2 = a2.restriction
    return false if r1 && !r2
    if r2 && r1 && r1 != r2
      # Check if a1.restriction is contravariant with a2.restriction
      begin
        rt1 = t1.lookup_type(r1, free_vars: free_vars1)
        rt2 = t2.lookup_type(r2, free_vars: free_vars2)
        return false unless rt2.implements?(rt1)
      rescue Crystal::TypeException
        # Ignore if we can't find a type (assume the method is implemented)
        return true
      end
    end

    true
  end

  def same_parameters?(m1 : Def, m2 : Def)
    return false unless m1.args.size == m2.args.size

    splat_index = m1.splat_index
    return false unless splat_index == m2.splat_index

    named_args1 = nil
    named_args2 = nil

    m1.args.each_with_index do |arg1, i|
      arg2 = m2.args[i]

      if splat_index
        if i > splat_index
          # named parameters may be in any order
          (named_args1 ||= [] of String) << arg1.external_name
          (named_args2 ||= [] of String) << arg2.external_name
          next
        elsif i == splat_index
          # single splat name may be different; bare splats must agree
          return false unless (arg1.external_name != "") == (arg2.external_name != "")
          next
        end
      end

      # positional parameter name must agree
      return false unless arg1.external_name == arg2.external_name
    end

    if named_args1 && named_args2
      named_args1.sort!
      named_args2.sort!
      return false unless named_args1 == named_args2
    end

    # double splat name may be different
    m1.double_splat.nil? == m2.double_splat.nil?
  end

  # Checks that the return type of `type#method` matches that of `base_type#base_method`
  # when computing that information for `target_type` (`type` is an ancestor of `target_type`).
  def check_return_type(target_type : Type, type : Type, method : Def, base_type : Type, base_method : Def)
    base_return_type_node = base_method.return_type
    return unless base_return_type_node

    original_base_return_type = base_type.lookup_type?(base_return_type_node)
    unless original_base_return_type
      report_error(base_return_type_node, "can't resolve return type #{base_return_type_node}")
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
      report_error(base_return_type_node, "can't resolve return type #{base_return_type_node}")
      return
    end

    return_type_node = method.return_type
    unless return_type_node
      report_error(method, "this method overrides #{Call.def_full_name(base_type, base_method)} which has an explicit return type of #{original_base_return_type}.\n#{@program.colorize("Please add an explicit return type (#{base_return_type} or a subtype of it) to this method as well.").yellow.bold}\n")
      return
    end

    return_type = type.lookup_type?(return_type_node)
    unless return_type
      report_error(return_type_node, "can't resolve return type #{return_type_node}")
      return
    end

    unless return_type.implements?(base_return_type)
      report_error(return_type_node, "this method must return #{base_return_type}, which is the return type of the overridden method #{Call.def_full_name(base_type, base_method)}, or a subtype of it, not #{return_type}")
      return
    end
  end

  def check_positional_param_names(impl_method : Def, base_type : Type, base_method : Def)
    impl_param_count = impl_method.splat_index || impl_method.args.size
    base_param_count = base_method.splat_index || base_method.args.size
    {impl_param_count, base_param_count}.min.times do |i|
      impl_param = impl_method.args[i]
      base_param = base_method.args[i]
      unless impl_param.external_name == base_param.external_name
        @program.warnings.add_warning(impl_param, "positional parameter '#{impl_param.external_name}' corresponds to parameter '#{base_param.external_name}' of the overridden method #{Call.def_full_name(base_type, base_method)}, which has a different name and may affect named argument passing")
      end
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

  private def report_error(node, message)
    node.raise(message, nil)
  end

  # Fictitious nodes for a given def's free vars, used to override type lookup
  # so that they are never shadowed by existing types. Type lookup will find
  # these Paths and raise because a Path isn't a type. (`#check_arg` relies on
  # ignoring undefined types for free vars to work, this should be improved in
  # the future.)
  private def free_var_nodes(a_def : Def)
    a_def.free_vars.try &.to_h do |var|
      {var, Path.new(var).as(TypeVar)}
    end
  end

  class ReplacePathWithTypeVar < Visitor
    def initialize(@base_type : GenericType, @generic_type : GenericInstanceType)
    end

    def visit(node : Path)
      if name = node.single_name?
        # Check if it matches any of the generic type vars
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

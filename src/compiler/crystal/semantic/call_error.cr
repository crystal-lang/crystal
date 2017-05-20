class Crystal::ASTNode
  def wrong_number_of_arguments(subject, given, expected)
    wrong_number_of "arguments", subject, given, expected
  end

  def wrong_number_of(elements, given, expected)
    raise wrong_number_of_message(elements, given, expected)
  end

  def wrong_number_of(elements, subject, given, expected)
    raise wrong_number_of_message(elements, subject, given, expected)
  end

  def wrong_number_of_message(elements, given, expected)
    "wrong number of #{elements} (given #{given}, expected #{expected})"
  end

  def wrong_number_of_message(elements, subject, given, expected)
    "wrong number of #{elements} for #{subject} (given #{given}, expected #{expected})"
  end
end

class Crystal::Path
  def raise_undefined_constant(type)
    private_const = type.lookup_path(self, include_private: true)
    if private_const
      self.raise("private constant #{private_const} referenced")
    end

    similar_name = type.lookup_similar_path(self)
    if similar_name
      self.raise("undefined constant #{self} #{type.program.colorize("(did you mean '#{similar_name}')").yellow.bold}")
    else
      self.raise("undefined constant #{self}")
    end
  end
end

class Crystal::Call
  def raise_matches_not_found(owner, def_name, arg_types, named_args_types, matches = nil)
    # Special case: Foo+:Class#new
    if owner.is_a?(VirtualMetaclassType) && def_name == "new"
      raise_matches_not_found_for_virtual_metaclass_new owner
    end

    if name == "super"
      defs = owner.lookup_defs_without_parents(def_name)
    else
      defs = owner.lookup_defs(def_name)
    end

    # Another special case: initialize is only looked up one level,
    # so we must find the first one defined.
    new_owner = owner
    while defs.empty? && def_name == "initialize"
      new_owner = new_owner.superclass
      if new_owner
        defs = new_owner.lookup_defs(def_name)
      else
        defs = [] of Def
        break
      end
    end

    # Check if it's the case of an abstract def
    check_abstract_def_error(owner, matches, defs, def_name)

    obj = @obj

    # Check if this is a `foo` call and we actually find it in the Program
    if !obj && defs.empty?
      program_defs = program.lookup_defs(def_name)
      unless program_defs.empty?
        defs = program_defs
        owner = program
      end
    end

    if defs.empty?
      check_macro_wrong_number_of_arguments(def_name)

      owner_trace = obj.try &.find_owner_trace(owner.program, owner)
      similar_name = owner.lookup_similar_def_name(def_name, self.args.size, block)

      error_msg = String.build do |msg|
        if obj && owner != program
          msg << "undefined method '#{def_name}' for #{owner}"
        elsif convert_to_logical_operator(def_name)
          msg << "undefined method '#{def_name}'"
          similar_name = convert_to_logical_operator(def_name)
        elsif args.size > 0 || has_parentheses?
          msg << "undefined method '#{def_name}'"
        else
          similar_name = parent_visitor.lookup_similar_var_name(def_name) unless similar_name
          if similar_name == def_name
            # This check is for the case `a if a = 1`
            msg << "undefined method '#{def_name}'"
          else
            msg << "undefined local variable or method '#{def_name}'"
          end
        end

        if obj && obj.type != owner
          msg << colorize(" (compile-time type is #{obj.type})").yellow.bold
        end

        if similar_name
          if similar_name == def_name
            # This check is for the case `a if a = 1`
            msg << colorize(" (If you declared '#{def_name}' in a suffix if, declare it in a regular if for this to work. If the variable was declared in a macro it's not visible outside it)").yellow.bold
          else
            msg << colorize(" (did you mean '#{similar_name}'?)").yellow.bold
          end
        end

        # Check if it's an instance variable that was never assigned a value
        if obj.is_a?(InstanceVar)
          scope = self.scope
          ivar = scope.lookup_instance_var(obj.name)
          deps = ivar.dependencies?
          if deps && deps.size == 1 && deps.first.same?(program.nil_var)
            similar_name = scope.lookup_similar_instance_var_name(ivar.name)
            if similar_name
              msg << colorize(" (#{ivar.name} was never assigned a value, did you mean #{similar_name}?)").yellow.bold
            else
              msg << colorize(" (#{ivar.name} was never assigned a value)").yellow.bold
            end
          end
        end
      end
      raise error_msg, owner_trace
    end

    real_args_size = arg_types.size

    # If it's on an initialize method and there's a similar method name, it's probably a typo
    if (def_name == "initialize" || def_name == "new") && (similar_def = owner.instance_type.lookup_similar_def("initialize", self.args.size, block))
      inner_msg = colorize("do you maybe have a typo in this '#{similar_def.name}' method?").yellow.bold.to_s
      inner_exception = TypeException.for_node(similar_def, inner_msg)
    end

    if owner_trace
      owner_trace.inner = inner_exception
      inner_exception = nil
    else
      owner_trace = inner_exception
    end

    defs_matching_args_size = defs.select do |a_def|
      min_size, max_size = a_def.min_max_args_sizes
      min_size <= real_args_size <= max_size
    end

    # Don't say "wrong number of arguments" when there are named args in this call
    if defs_matching_args_size.empty? && !named_args_types
      all_arguments_sizes = [] of Int32
      min_splat = Int32::MAX
      defs.each do |a_def|
        min_size, max_size = a_def.min_max_args_sizes
        if max_size == Int32::MAX
          min_splat = Math.min(min_size, min_splat)
          all_arguments_sizes.push min_splat
        else
          min_size.upto(max_size) do |size|
            all_arguments_sizes.push size
          end
        end
      end
      all_arguments_sizes.uniq!.sort!

      raise(String.build do |str|
        unless check_single_def_error_message(defs, named_args_types, str)
          str << "wrong number of arguments for '"
          str << full_name(owner, def_name)
          str << "' (given "
          str << real_args_size
          str << ", expected "

          # If we have 2, 3, 4, show it as 2..4
          if all_arguments_sizes.size > 1 && all_arguments_sizes.last - all_arguments_sizes.first == all_arguments_sizes.size - 1
            str << all_arguments_sizes.first
            str << ".."
            str << all_arguments_sizes.last
          else
            all_arguments_sizes.join ", ", str
          end

          str << "+" if min_splat != Int32::MAX
          str << ")\n"
        end
        str << "Overloads are:"
        append_matches(defs, arg_types, str)
      end, inner: inner_exception)
    end

    if defs_matching_args_size.size > 0
      str = IO::Memory.new
      if check_single_def_error_message(defs_matching_args_size, named_args_types, str)
        raise str.to_s
      else
        if block && defs_matching_args_size.all? { |a_def| !a_def.yields }
          raise "'#{full_name(owner, def_name)}' is not expected to be invoked with a block, but a block was given"
        elsif !block && defs_matching_args_size.all?(&.yields)
          raise "'#{full_name(owner, def_name)}' is expected to be invoked with a block, but no block was given"
        end

        if named_args_types
          defs_matching_args_size.each do |a_def|
            check_named_args_mismatch owner, arg_types, named_args_types, a_def
          end
        end
      end
    end

    if args.size == 1 && args.first.type.includes_type?(program.nil)
      owner_trace = args.first.find_owner_trace(program, program.nil)
    end

    arg_names = [] of Array(String)

    message = String.build do |msg|
      unless check_single_def_error_message(defs, named_args_types, msg)
        msg << "no overload matches '#{full_name(owner, def_name)}'"
        unless args.empty?
          msg << " with type"
          msg << "s" if arg_types.size > 1 || named_args_types
          msg << " "
          arg_types.join(", ", msg)
        end

        if named_args_types
          named_args_types.each do |named_arg|
            msg << ", "
            msg << named_arg.name
            msg << ": "
            msg << named_arg.type
          end
        end

        msg << "\n"

        defs.each do |a_def|
          arg_names.try &.push a_def.args.map(&.name)
        end
      end

      msg << "Overloads are:"
      append_matches(defs, arg_types, msg)

      if matches
        cover = matches.cover
        if cover.is_a?(Cover)
          missing = cover.missing
          uniq_arg_names = arg_names.uniq!
          uniq_arg_names = uniq_arg_names.size == 1 ? uniq_arg_names.first : nil
          unless missing.empty?
            msg << "\nCouldn't find overloads for these types:"
            missing.each_with_index do |missing_types|
              if uniq_arg_names
                signature_names = missing_types.map_with_index do |missing_type, i|
                  if i >= arg_types.size && (named_arg = named_args_types.try &.[i - arg_types.size]?)
                    "#{named_arg.name} : #{missing_type}"
                  else
                    "#{uniq_arg_names[i]? || "_"} : #{missing_type}"
                  end
                end
                signature_args = signature_names.join ", "
              else
                signature_args = missing_types.join ", "
              end
              msg << "\n - #{full_name(owner, def_name)}(#{signature_args}"
              msg << ", &block" if block
              msg << ")"
            end
          end
        end
      end
    end

    raise message, owner_trace
  end

  def convert_to_logical_operator(def_name)
    case def_name
    when "and"; "&&"
    when "or" ; "||"
    when "not"; "!"
    else        nil
    end
  end

  # If there's only one def that could match, and there are named
  # arguments in this call, we can give a better error message.
  def check_single_def_error_message(defs, named_args, io)
    return false unless defs.size == 1

    a_def = defs.first

    if msg = check_named_args_and_splats(a_def, named_args)
      io << msg
      io.puts
      return true
    end

    false
  end

  def check_named_args_and_splats(a_def, named_args)
    splat_index = a_def.splat_index
    return if !splat_index && !named_args
    return if splat_index == a_def.args.size - 1

    # Check if some mandatory arguments are missing
    mandatory_args = BitArray.new(a_def.args.size)
    a_def.match(args) do |arg, arg_index, call_arg, call_arg_index|
      mandatory_args[arg_index] = true
    end

    named_args.try &.each do |named_arg|
      found_index = a_def.args.index { |arg| arg.external_name == named_arg.name }
      if found_index
        mandatory_args[found_index] = true
      end
    end

    missing_args = [] of String
    mandatory_args.each_with_index do |value, index|
      next if value

      arg = a_def.args[index]
      next if arg.default_value
      next if arg.external_name.empty?

      missing_args << arg.external_name
    end

    case missing_args.size
    when 0
      # Nothing
    when 1
      return "missing argument: #{missing_args.first}"
    else
      return "missing arguments: #{missing_args.join ", "}"
    end

    return nil
  end

  def append_error_when_no_matching_defs(owner, def_name, all_arguments_sizes, real_args_size, min_splat, defs, io)
  end

  def check_abstract_def_error(owner, matches, defs, def_name)
    return unless !matches || (matches.try &.empty?)
    return unless defs.all? &.abstract?

    named_args_types = NamedArgumentType.from_args(named_args)
    signature = CallSignature.new(def_name, args.map(&.type), block, named_args_types)
    defs.each do |a_def|
      context = MatchContext.new(owner, a_def.owner, def_free_vars: a_def.free_vars)
      match = signature.match(DefWithMetadata.new(a_def), context)
      next unless match

      if a_def.owner == owner
        owner.all_subclasses.each do |subclass|
          submatches = subclass.lookup_matches(signature)
          if submatches.empty?
            raise_abstract_method_must_be_implemented a_def, subclass
          end
        end
        raise_abstract_method_must_be_implemented a_def, owner
      else
        raise_abstract_method_must_be_implemented a_def, owner
      end
    end
  end

  def raise_abstract_method_must_be_implemented(a_def, owner)
    if owner.abstract?
      raise "undefined method '#{def_full_name(a_def.owner, a_def)}'"
    else
      raise "abstract `def #{def_full_name(a_def.owner, a_def)}` must be implemented by #{owner}"
    end
  end

  def append_matches(defs, arg_types, str, *, matched_def = nil, argument_name = nil)
    defs.each do |a_def|
      str << "\n - "
      append_def_full_name a_def.owner, a_def, arg_types, str
      if defs.size > 1 && a_def.same?(matched_def)
        str << colorize(" (trying this one)").blue
      end
      if a_def.args.any? { |arg| arg.default_value && arg.external_name == argument_name }
        str << colorize(" (did you mean this one?)").yellow.bold
      end
    end
  end

  def def_full_name(owner, a_def, arg_types = nil)
    Call.def_full_name(owner, a_def, arg_types = nil)
  end

  def self.def_full_name(owner, a_def, arg_types = nil)
    String.build { |io| append_def_full_name(owner, a_def, arg_types, io) }
  end

  def append_def_full_name(owner, a_def, arg_types, str)
    Call.append_def_full_name(owner, a_def, arg_types, str)
  end

  def self.append_def_full_name(owner, a_def, arg_types, str)
    str << full_name(owner, a_def.name)
    str << '('
    printed = false
    a_def.args.each_with_index do |arg, i|
      str << ", " if printed
      str << '*' if a_def.splat_index == i

      if arg.external_name != arg.name
        str << (arg.external_name.empty? ? "_" : arg.external_name)
        str << " "
      end

      str << arg.name

      if arg_type = arg.type?
        str << " : "
        str << arg_type
      elsif res = arg.restriction
        str << " : "
        if owner.is_a?(GenericClassInstanceType) && res.is_a?(Path) && res.names.size == 1 &&
           (type_var = owner.type_vars[res.names[0]]?)
          str << type_var.type
        else
          # Try to use the full name if the argument type and the call
          # argument type have the same string representation
          res_to_s = res.to_s
          if (arg_type = arg_types.try &.[i]?) && arg_type.to_s == res_to_s &&
             (matching_type = a_def.owner.lookup_type?(res))
            str << matching_type
          else
            str << res_to_s
          end
        end
      end
      if arg_default = arg.default_value
        str << " = "
        str << arg.default_value
      end
      printed = true
    end

    if a_def.double_splat
      str << ", " if printed
      str << "**" << a_def.double_splat
      printed = true
    end

    if block_arg = a_def.block_arg
      str << ", " if printed
      str << "&" << block_arg.name
    elsif a_def.yields
      str << ", " if printed
      str << "&block"
    end
    str << ")"
  end

  def raise_matches_not_found_for_virtual_metaclass_new(owner)
    arg_types = args.map &.type

    owner.each_concrete_type do |concrete_type|
      defs = concrete_type.instance_type.lookup_defs_with_modules("initialize")
      defs = defs.select { |a_def| a_def.args.size != args.size }
      unless defs.empty?
        all_arguments_sizes = Set(Int32).new
        defs.each { |a_def| all_arguments_sizes << a_def.args.size }
        wrong_number_of_arguments "'#{concrete_type.instance_type}#initialize'", args.size, all_arguments_sizes.join(", ")
      end
    end
  end

  def check_macro_wrong_number_of_arguments(def_name)
    obj = self.obj
    return if obj && !obj.is_a?(Path)

    macros = in_macro_target &.lookup_macros(def_name)
    return unless macros.is_a?(Array(Macro))
    macros = macros.reject &.visibility.private?

    if macros.size == 1
      if msg = check_named_args_and_splats(macros.first, named_args)
        raise msg
      end
    end

    all_arguments_sizes = Set(String).new
    macros.each do |a_macro|
      named_args.try &.each do |named_arg|
        index = a_macro.args.index { |arg| arg.external_name == named_arg.name }
        if index
          if index < args.size
            raise "argument '#{named_arg.name}' already specified"
          end
        else
          raise "no argument named '#{named_arg.name}'"
        end
      end

      plus = false

      splat_index = a_macro.splat_index
      if splat_index
        if a_macro.args[splat_index].name.empty?
          min_size = max_size = splat_index
        else
          min_size = splat_index
          max_size = a_macro.args.size
          plus = true
        end
      else
        min_size = a_macro.args.index(&.default_value) || a_macro.args.size
        max_size = a_macro.args.size
      end

      if plus
        all_arguments_sizes << "#{min_size}+"
      else
        min_size.upto(max_size) do |args_size|
          all_arguments_sizes << args_size.to_s
        end
      end
    end

    wrong_number_of_arguments "macro '#{def_name}'", args.size, all_arguments_sizes.join(", ")
  end

  def check_named_args_mismatch(owner, arg_types, named_args, a_def)
    named_args.each do |named_arg|
      found_index = a_def.args.index { |arg| arg.external_name == named_arg.name }
      if found_index
        min_size = args.size
        if found_index < min_size
          raise "argument '#{named_arg.name}' already specified"
        end
      elsif !a_def.double_splat
        similar_name = Levenshtein.find(named_arg.name, a_def.args.select(&.default_value).map(&.external_name))

        msg = String.build do |str|
          str << "no argument named '"
          str << named_arg.name
          str << "'"
          if similar_name
            str << colorize(" (did you mean '#{similar_name}'?)").yellow.bold
          end

          defs = owner.lookup_defs(a_def.name)

          str << "\n"
          str << "Matches are:"
          append_matches defs, arg_types, str, matched_def: a_def, argument_name: named_arg.name
        end
        raise msg
      end
    end
  end

  def check_visibility(match)
    case match.def.visibility
    when .private?
      if obj = @obj
        if obj.is_a?(Var) && obj.name == "self" && match.def.name.ends_with?('=')
          # Special case: private setter can be called with self
          return
        end

        if name == "initialize" && parent_visitor.call.try(&.name) == "new"
          # Special case: initialize call inside automatically defined new
          return
        end

        raise "private method '#{match.def.name}' called for #{match.def.owner}"
      end
    when .protected?
      scope_type = scope.instance_type
      owner_type = match.def.owner.instance_type

      # OK if in the same hierarchy,
      # either because scope_type < owner_type
      return if scope_type.implements?(owner_type)

      # or because owner_type < scope_type
      return if owner_type.implements?(scope_type)

      # OK if both types are in the same namespace
      return if in_same_namespace?(scope_type, owner_type)

      raise "protected method '#{match.def.name}' called for #{match.def.owner}"
    end
  end

  def in_same_namespace?(scope, target)
    top_namespace(scope) == top_namespace(target) ||
      scope.parents.try &.any? { |parent| in_same_namespace?(parent, target) }
  end

  def top_namespace(type)
    namespace = case type
                when NamedType
                  type.namespace
                when GenericClassInstanceType
                  type.namespace
                else
                  nil
                end
    case namespace
    when Program
      type
    when NamedType, GenericClassInstanceType
      top_namespace(namespace)
    else
      type
    end
  end

  def check_recursive_splat_call(a_def, args)
    if a_def.splat_index
      current_splat_type = args.values.last.type
      if previous_splat_type = program.splat_expansions[a_def.object_id]?
        if current_splat_type.has_in_type_vars?(previous_splat_type)
          raise "recursive splat expansion: #{previous_splat_type}, #{current_splat_type}, ..."
        end
      end
      program.splat_expansions[a_def.object_id] = current_splat_type
      yield
      program.splat_expansions.delete a_def.object_id
    else
      yield
    end
  end

  def full_name(owner, def_name = name)
    Call.full_name(owner, def_name)
  end

  def self.full_name(owner, method_name = name)
    case owner
    when Program
      method_name
    when .metaclass?
      "#{owner.instance_type}.#{method_name}"
    else
      "#{owner}##{method_name}"
    end
  end

  private def colorize(obj)
    program.colorize(obj)
  end
end

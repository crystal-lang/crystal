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
      self.raise("undefined constant #{self}\nDid you mean '#{similar_name}'?")
    else
      self.raise("undefined constant #{self}")
    end
  end
end

class Crystal::Call
  # :nodoc:
  MAX_RENDERED_OVERLOADS = 20

  def raise_matches_not_found(owner, def_name, arg_types, named_args_types, matches = nil, with_autocast = false, number_autocast = true)
    obj = @obj
    with_scope = @with_scope

    # Special case: Foo+.class#new
    if owner.is_a?(VirtualMetaclassType) && def_name == "new"
      raise_matches_not_found_for_virtual_metaclass_new owner
    end

    if super?
      defs = owner.lookup_defs_without_parents(def_name)
    else
      defs = owner.lookup_defs(def_name)
    end

    # Also consider private top-level defs
    if owner.is_a?(Program)
      location = self.location
      if location && (filename = location.original_filename)
        private_defs = owner.file_module?(filename).try &.lookup_defs(def_name)
        defs.concat(private_defs) if private_defs
      end
    end

    # Another special case: `new` and `initialize` are only looked up one level,
    # so we must find the first one defined.
    new_owner = owner
    while defs.empty? && def_name.in?("initialize", "new")
      new_owner = new_owner.superclass
      if new_owner
        defs = new_owner.lookup_defs(def_name)
      else
        defs = [] of Def
        break
      end
    end

    # Also check with scope
    if with_scope
      defs.concat with_scope.lookup_defs(def_name)
    end

    # Check if it's the case of an abstract def
    check_abstract_def_error(owner, matches, defs, def_name)

    # Check if this is a `foo` call and we actually find it in the Program
    if !obj && defs.empty?
      program_defs = program.lookup_defs(def_name)
      unless program_defs.empty?
        defs = program_defs
        owner = program
      end
    end

    if defs.empty?
      raise_undefined_method(owner, def_name, obj)
    end

    # If we made a lookup without the special rule for literals,
    # and we have literals in the call, try again with that special rule.
    if !with_autocast && (args.any?(&.supports_autocast? number_autocast) ||
       named_args.try &.any? &.value.supports_autocast? number_autocast)
      ::raise RetryLookupWithLiterals.new
    end

    # If it's on an initialize method and there's a similar method name, it's probably a typo
    if def_name.in?("initialize", "new") && (similar_def = owner.instance_type.lookup_similar_def("initialize", self.args.size, block))
      inner_msg = colorize("do you maybe have a typo in this '#{similar_def.name}' method?").yellow.bold.to_s
      inner_exception = TypeException.for_node(similar_def, inner_msg)
    end

    # Check why each def can't be called with this Call (what's the error?)
    call_errors = defs.map do |a_def|
      compute_call_error_reason(owner, a_def, arg_types, named_args_types)
    end

    check_block_mismatch(call_errors, owner, def_name)
    call_errors.reject!(BlockMismatch)

    check_missing_named_arguments(call_errors, owner, defs, arg_types, inner_exception)
    check_extra_named_arguments(call_errors, owner, defs, arg_types, inner_exception)
    check_arguments_already_specified(call_errors, owner, defs, arg_types, inner_exception)
    check_wrong_number_of_arguments(call_errors, owner, defs, def_name, arg_types, named_args_types, inner_exception)
    check_extra_types_arguments_mismatch(call_errors, owner, defs, def_name, arg_types, named_args_types, inner_exception)
    check_arguments_type_mismatch(call_errors, owner, defs, def_name, arg_types, named_args_types, inner_exception)

    if args.size == 1 && args.first.type.includes_type?(program.nil)
      owner_trace = args.first.find_owner_trace(program, program.nil)
    else
      owner_trace = inner_exception
    end

    message = String.build do |msg|
      no_overload_matches_message(msg, full_name(owner, def_name), defs, args, arg_types, named_args_types)

      msg << "Overloads are:"
      append_matches(defs, arg_types, msg)

      if matches
        cover = matches.cover
        if cover.is_a?(Cover)
          missing = cover.missing

          uniq_arg_names = defs.map(&.args.map(&.name)).uniq!
          uniq_arg_names = uniq_arg_names.size == 1 ? uniq_arg_names.first : nil
          unless missing.empty?
            msg << "\nCouldn't find overloads for these types:"

            missing.first(MAX_RENDERED_OVERLOADS).each do |missing_types|
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
              msg << ')'
            end

            if missing.size > MAX_RENDERED_OVERLOADS
              msg << "\nAnd #{missing.size - MAX_RENDERED_OVERLOADS} more..."
            end
          end
        end
      end
    end

    raise message, owner_trace
  end

  private def check_block_mismatch(call_errors, owner, def_name)
    return unless call_errors.all?(BlockMismatch)

    error_message =
      if block
        "'#{full_name(owner, def_name)}' is not expected to be invoked with a block, but a block was given"
      else
        "'#{full_name(owner, def_name)}' is expected to be invoked with a block, but no block was given"
      end

    raise error_message
  end

  private def check_missing_named_arguments(call_errors, owner, defs, arg_types, inner_exception)
    gather_names_in_all_overloads(call_errors, MissingNamedArguments) do |call_errors, names|
      raise_no_overload_matches(self, defs, arg_types, inner_exception) do |str|
        if names.size == 1
          str << "missing argument: #{names.first}"
        else
          str << "missing arguments: #{names.join ", "}"
        end
      end
    end
  end

  private def check_extra_named_arguments(call_errors, owner, defs, arg_types, inner_exception)
    gather_names_in_all_overloads(call_errors, ExtraNamedArguments) do |call_errors, names|
      raise_no_overload_matches(self, defs, arg_types, inner_exception) do |str|
        quoted_names = names.map { |name| "'#{name}'" }

        if quoted_names.size == 1
          str << "no parameter named #{quoted_names.first}"
        else
          str << "no parameters named #{quoted_names.join ", "}"
        end

        # Show did you mean for the simplest case for now
        if names.size == 1 && call_errors.size == 1
          extra_name = names.first
          name_index = call_errors.first.names.index!(extra_name)
          similar_name = call_errors.first.similar_names[name_index]
          if similar_name
            str.puts
            str << "Did you mean '#{similar_name}'?"
          end
        end
      end
    end
  end

  private def check_arguments_already_specified(call_errors, owner, defs, arg_types, inner_exception)
    gather_names_in_all_overloads(call_errors, ArgumentsAlreadySpecified) do |call_errors, names|
      raise_no_overload_matches(self, defs, arg_types, inner_exception) do |str|
        quoted_names = names.map { |name| "'#{name}'" }

        if quoted_names.size == 1
          str << "argument for parameter #{quoted_names.first} already specified"
        else
          str << "arguments for parameters #{quoted_names.join ", "} already specified"
        end
      end
    end
  end

  private def gather_names_in_all_overloads(call_errors, error_type : T.class, &) forall T
    return unless call_errors.all?(T)

    call_errors = call_errors.map &.as(T)
    all_names = call_errors.flat_map(&.names).uniq!
    names_in_all_overloads = all_names.select do |missing_name|
      call_errors.all? &.names.includes?(missing_name)
    end
    unless names_in_all_overloads.empty?
      yield call_errors, names_in_all_overloads
    end
  end

  private def check_wrong_number_of_arguments(call_errors, owner, defs, def_name, arg_types, named_args_types, inner_exception)
    return unless call_errors.all?(WrongNumberOfArguments)

    raise_matches_not_found_named_args(owner, def_name, defs, arg_types, named_args_types, inner_exception)
  end

  private def check_extra_types_arguments_mismatch(call_errors, owner, defs, def_name, arg_types, named_args_types, inner_exception)
    call_errors = call_errors.select(ArgumentsTypeMismatch)
    return if call_errors.empty?

    call_errors = call_errors.map &.as(ArgumentsTypeMismatch)
    argument_type_mismatches = call_errors.flat_map(&.errors)

    argument_type_mismatches.select!(&.extra_types)
    return if argument_type_mismatches.empty?

    argument_type_mismatches.each do |target_error|
      index_or_name = target_error.index_or_name

      mismatches = argument_type_mismatches.select(&.index_or_name.==(index_or_name))
      expected_types = mismatches.map(&.expected_type).uniq!
      actual_type = mismatches.first.actual_type

      actual_types =
        if actual_type.is_a?(UnionType)
          actual_type.union_types
        else
          [actual_type] of Type
        end

      # It could happen that a type that's missing in one overload is actually
      # covered in another overload, and eventually all overloads are covered
      if expected_types.to_set == actual_types.to_set
        expected_types = [target_error.expected_type]
      end

      raise_argument_type_mismatch(index_or_name, actual_type, expected_types.sort_by!(&.to_s), owner, defs, def_name, arg_types, inner_exception)
    end
  end

  private def check_arguments_type_mismatch(call_errors, owner, defs, def_name, arg_types, named_args_types, inner_exception)
    call_errors = call_errors.select(ArgumentsTypeMismatch)
    return if call_errors.empty?

    call_errors = call_errors.map &.as(ArgumentsTypeMismatch)
    argument_type_mismatches = call_errors.flat_map(&.errors)

    all_indexes_or_names = argument_type_mismatches.map(&.index_or_name).uniq!
    indexes_or_names_in_all_overloads = all_indexes_or_names.select do |index_or_name|
      call_errors.all? &.errors.any? &.index_or_name.==(index_or_name)
    end

    return if indexes_or_names_in_all_overloads.empty?

    # Only show the first error. We'll still list all overloads.
    index_or_name = indexes_or_names_in_all_overloads.first

    mismatches = argument_type_mismatches.select(&.index_or_name.==(index_or_name))
    expected_types = mismatches.map(&.expected_type).uniq!.sort_by!(&.to_s)
    actual_type = mismatches.first.actual_type

    raise_argument_type_mismatch(index_or_name, actual_type, expected_types, owner, defs, def_name, arg_types, inner_exception)
  end

  private def raise_argument_type_mismatch(index_or_name, actual_type, expected_types, owner, defs, def_name, arg_types, inner_exception)
    arg =
      case index_or_name
      in Int32
        args[index_or_name]?
      in String
        named_args.try &.find(&.name.==(index_or_name))
      end

    enum_types = expected_types.select(EnumType)
    if actual_type.is_a?(SymbolType) && enum_types.size == 1
      enum_type = enum_types.first

      if arg.is_a?(SymbolLiteral)
        symbol = arg.value
      elsif arg.is_a?(NamedArgument) && (named_arg_value = arg.value).is_a?(SymbolLiteral)
        symbol = named_arg_value.value
      end
    end

    raise_no_overload_matches(arg || self, defs, arg_types, inner_exception) do |str|
      argument_description =
        case index_or_name
        in Int32
          "##{index_or_name + 1}"
        in String
          "'#{index_or_name}'"
        end

      if symbol && enum_type
        str << "expected argument #{argument_description} to '#{full_name(owner, def_name)}' to match a member of enum #{enum_type}."
        str.puts
        str.puts

        options = enum_type.types.map(&.[1].name.underscore)
        similar_name = Levenshtein.find(symbol.underscore, options)
        if similar_name
          str << "Did you mean :#{similar_name}?"
        elsif options.size <= 10
          str << "Options are: "
          to_sentence(str, options.map { |o| ":#{o}" }, " and ")
        end
      else
        str << "expected argument #{argument_description} to '#{full_name(owner, def_name)}' to be "
        to_sentence(str, expected_types, " or ")
        str << ", not #{actual_type.devirtualize}"
      end
    end
  end

  private def to_sentence(str : IO, elements : Array, last_connector : String)
    elements.each_with_index do |element, i|
      if i == elements.size - 1 && elements.size > 1
        str << last_connector
      elsif i > 0
        str << ", "
      end
      str << element
    end
  end

  private def raise_no_overload_matches(node, defs, arg_types, inner_exception, &)
    error_message = String.build do |str|
      yield str

      str.puts
      str.puts
      str << "Overloads are:"
      append_matches(defs, arg_types, str)
    end

    node.raise(error_message, inner_exception)
  end

  record WrongNumberOfArguments
  record MissingNamedArguments, names : Array(String)
  record BlockMismatch
  record ExtraNamedArguments, names : Array(String), similar_names : Array(String?)
  record ArgumentsAlreadySpecified, names : Array(String)
  record ArgumentsTypeMismatch, errors : Array(ArgumentTypeMismatch)
  record ArgumentTypeMismatch,
    index_or_name : (Int32 | String),
    expected_type : Type | ASTNode,
    actual_type : Type,
    extra_types : Array(Type)?

  private def compute_call_error_reason(owner, a_def, arg_types, named_args_types)
    if (block && !a_def.block_arity) || (!block && a_def.block_arity)
      return BlockMismatch.new
    end

    if !named_args_types
      min_size, max_size = a_def.min_max_args_sizes
      unless min_size <= arg_types.size <= max_size
        return WrongNumberOfArguments.new
      end
    end

    missing_named_args = extract_missing_named_args(a_def, named_args)
    if missing_named_args
      return MissingNamedArguments.new(missing_named_args)
    end

    arguments_already_specified = [] of String
    extra_named_argument_names = [] of String
    extra_named_argument_similar_names = [] of String?

    named_args_types.try &.each do |named_arg|
      found_index = a_def.args.index { |arg| arg.external_name == named_arg.name }
      if found_index
        min_size = arg_types.size
        if found_index < min_size
          arguments_already_specified << named_arg.name
        end
      elsif !a_def.double_splat
        similar_name = Levenshtein.find(named_arg.name, a_def.args.select(&.default_value).map(&.external_name))

        extra_named_argument_names << named_arg.name
        extra_named_argument_similar_names << similar_name
      end
    end

    unless arguments_already_specified.empty?
      return ArgumentsAlreadySpecified.new(arguments_already_specified)
    end

    unless extra_named_argument_names.empty?
      return ExtraNamedArguments.new(extra_named_argument_names, extra_named_argument_similar_names)
    end

    # For now let's not deal with splats
    return if a_def.splat_index

    a_def_owner = a_def.owner

    # This is the actual instantiated type where the method was instantiated
    instantiated_owner = owner

    owner.ancestors.each do |ancestor|
      if a_def_owner == ancestor
        instantiated_owner = ancestor
        break
      end

      # If the method is defined in a generic uninstantiated type
      # then the method instantiation happens on the instantiated generic
      # type whose generic type is that uninstantiated one.
      if a_def_owner.is_a?(GenericType) &&
         ancestor.is_a?(GenericInstanceType) &&
         ancestor.generic_type == a_def_owner
        instantiated_owner = ancestor
        break
      end
    end

    match_context = MatchContext.new(
      instantiated_type: instantiated_owner,
      defining_type: instantiated_owner,
      def_free_vars: a_def.free_vars,
    )

    arguments_type_mismatch = [] of ArgumentTypeMismatch

    arg_types.each_with_index do |arg_type, i|
      def_arg = a_def.args[i]?
      next unless def_arg

      check_argument_type_mismatch(def_arg, i, arg_type, match_context, arguments_type_mismatch)
    end

    named_args_types.try &.each do |named_arg|
      def_arg = a_def.args.find &.external_name.==(named_arg.name)
      next unless def_arg

      check_argument_type_mismatch(def_arg, named_arg.name, named_arg.type, match_context, arguments_type_mismatch)
    end

    unless arguments_type_mismatch.empty?
      return ArgumentsTypeMismatch.new(arguments_type_mismatch)
    end

    nil
  end

  private def check_argument_type_mismatch(def_arg, index_or_name, arg_type, match_context, arguments_type_mismatch)
    restricted = arg_type.restrict(def_arg, match_context)

    arg_type = arg_type.remove_literal
    return if restricted == arg_type

    expected_type = compute_expected_type(def_arg, match_context)

    extra_types =
      if restricted
        # This was a partial match
        compute_extra_types(arg_type, expected_type)
      else
        # This wasn't a match
        nil
      end

    arguments_type_mismatch << ArgumentTypeMismatch.new(
      index_or_name: index_or_name,
      expected_type: expected_type,
      actual_type: arg_type.remove_literal,
      extra_types: extra_types,
    )
  end

  private def compute_expected_type(def_arg, match_context)
    expected_type = def_arg.type?
    unless expected_type
      restriction = def_arg.restriction
      if restriction
        expected_type = match_context.instantiated_type.lookup_type?(restriction, free_vars: match_context.bound_free_vars)
      end
    end
    expected_type ||= def_arg.restriction.not_nil!
    expected_type = expected_type.devirtualize if expected_type.is_a?(Type)
    expected_type
  end

  private def compute_extra_types(actual_type, expected_type)
    expected_types =
      if expected_type.is_a?(UnionType)
        expected_type.union_types
      elsif expected_type.is_a?(Type)
        [expected_type] of Type
      else
        return
      end

    actual_types =
      if actual_type.is_a?(UnionType)
        actual_type.union_types
      else
        [actual_type] of Type
      end

    actual_types - expected_types
  end

  private def no_overload_matches_message(io, full_name, defs, args, arg_types, named_args_types)
    if message = single_def_error_message(defs, named_args_types)
      io << message
      io << '\n'
      return
    end

    io << "no overload matches '#{full_name}'"
    unless args.empty?
      io << " with type"
      io << 's' if arg_types.size > 1 || named_args_types
      io << ' '
      arg_types.join(io, ", ")
    end

    if named_args_types
      named_args_types.each do |named_arg|
        io << ", "
        io << named_arg.name
        io << ": "
        io << named_arg.type
      end
    end

    io << '\n'
  end

  private def raise_undefined_method(owner, def_name, obj)
    check_macro_wrong_number_of_arguments(def_name)

    owner_trace = obj.try &.find_owner_trace(owner.program, owner)
    similar_name = owner.lookup_similar_def_name(def_name, self.args.size, block)

    error_msg = String.build do |msg|
      if obj
        could_be_local_variable = false
      elsif logical_op = convert_to_logical_operator(def_name)
        similar_name = logical_op
        could_be_local_variable = false
      elsif args.size > 0 || has_parentheses?
        could_be_local_variable = false
      else
        # This check is for the case `a if a = 1`
        similar_name = parent_visitor.lookup_similar_var_name(def_name) unless similar_name
        could_be_local_variable = (similar_name != def_name)
      end

      if could_be_local_variable
        msg << "undefined local variable or method '#{def_name}'"
      else
        msg << "undefined method '#{def_name}'"
      end

      owner_name = owner.is_a?(Program) ? "top-level" : owner.to_s

      if with_scope && !obj && with_scope != owner
        msg << " for #{with_scope} (with ... yield) and #{owner_name} (current scope)"
      else
        msg << " for #{owner_name}"
      end

      if def_name == "allocate" && owner.is_a?(MetaclassType) && owner.instance_type.module?
        msg << colorize(" (modules cannot be instantiated)").yellow.bold
      end

      if obj && obj.type != owner
        msg << colorize(" (compile-time type is #{obj.type})").yellow.bold
      end

      if similar_name
        msg << '\n'
        if similar_name == def_name
          # This check is for the case `a if a = 1`
          msg << "If you declared '#{def_name}' in a suffix if, declare it in a regular if for this to work. If the variable was declared in a macro it's not visible outside it."
        else
          msg << "Did you mean '#{similar_name}'?"
        end
      end

      # Check if it's an instance variable that was never assigned a value
      if obj.is_a?(InstanceVar)
        scope = self.scope
        ivar = scope.lookup_instance_var(obj.name)
        if ivar.dependencies.size == 1 && ivar.dependencies.first.same?(program.nil_var)
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

  private def raise_matches_not_found_named_args(owner, def_name, defs, arg_types, named_args_types, inner_exception)
    all_arguments_sizes = [] of Int32
    min_splat = Int32::MAX
    defs.each do |a_def|
      next if (block && !a_def.block_arity) || (!block && a_def.block_arity)

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
      if single_message = single_def_error_message(defs, named_args_types)
        str << single_message
        str << '\n'
      else
        str << "wrong number of arguments for '"
        str << full_name(owner, def_name)
        str << "' (given "
        str << arg_types.size
        str << ", expected "

        # If we have 2, 3, 4, show it as 2..4
        if all_arguments_sizes.size > 1 && all_arguments_sizes.last - all_arguments_sizes.first == all_arguments_sizes.size - 1
          str << all_arguments_sizes.first
          str << ".."
          str << all_arguments_sizes.last
        else
          all_arguments_sizes.join str, ", "
        end

        str << '+' if min_splat != Int32::MAX
        str << ")\n"
      end
      str << "Overloads are:"
      append_matches(defs, arg_types, str)
    end, inner: inner_exception)
  end

  def convert_to_logical_operator(def_name)
    case def_name
    when "and"; "&&"
    when "or" ; "||"
    when "not"; "!"
    else        nil
    end
  end

  def single_def_error_message(defs, named_args)
    if defs.size == 1
      missing_argument_message(defs.first, named_args)
    end
  end

  def missing_argument_message(a_def, named_args)
    missing_args = extract_missing_named_args(a_def, named_args)
    return unless missing_args

    if missing_args.size == 1
      "missing argument: #{missing_args.first}"
    else
      "missing arguments: #{missing_args.join ", "}"
    end
  end

  def extract_missing_named_args(a_def, named_args)
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

    return if missing_args.size.zero?

    missing_args
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
      next if a_def.abstract?
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
    Call.def_full_name(owner, a_def, arg_types)
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
        str << (arg.external_name.presence || '_')
        str << ' '
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
        str << arg_default
      end
      printed = true
    end

    if a_def.double_splat
      str << ", " if printed
      str << "**" << a_def.double_splat
      printed = true
    end

    if a_def.block_arity
      str << ", " if printed
      str << '&'
      if block_arg = a_def.block_arg
        str << block_arg
      end
    end
    str << ')'

    if free_vars = a_def.free_vars
      str << " forall "
      free_vars.join(str, ", ")
    end
  end

  def raise_matches_not_found_for_virtual_metaclass_new(owner)
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
    return if (obj = self.obj) && !obj.is_a?(Path)

    macros = in_macro_target &.lookup_macros(def_name)
    return unless macros.is_a?(Array(Macro))

    if msg = single_def_error_message(macros, named_args)
      raise msg
    end

    all_arguments_sizes = Set(String).new
    macros.each do |a_macro|
      named_args.try &.each do |named_arg|
        index = a_macro.args.index { |arg| arg.external_name == named_arg.name }
        if index
          if index < args.size
            raise "argument for parameter '#{named_arg.name}' already specified"
          end
        else
          raise "no parameter named '#{named_arg.name}'"
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

  def check_visibility(match)
    case match.def.visibility
    when .private?
      if obj = @obj
        if obj.is_a?(Var) && obj.name == "self"
          # Special case: private method can be called with self
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

      unless scope_type.has_protected_access_to?(owner_type)
        raise "protected method '#{match.def.name}' called for #{match.def.owner}"
      end
    when .public?
      # okay
    end
  end

  def check_recursive_splat_call(a_def, args, &)
    if a_def.splat_index
      previous_splat_types = program.splat_expansions[a_def] ||= [] of Type
      previous_splat_types.push(args.values.last.type)

      # This is just an heuristic, but if a same method is called recursively
      # 5 times or more, and the splat type keeps expanding and containing
      # previous splat types, there's a high chance it will recurse forever.
      if previous_splat_types.size >= 5 &&
         previous_splat_types.each.cons_pair.all? { |t1, t2| t2.has_in_type_vars?(t1) }
        a_def.raise "recursive splat expansion: #{previous_splat_types.join(", ")}, ..."
      end

      yield

      previous_splat_types.pop
      program.splat_expansions.delete a_def if previous_splat_types.empty?
    else
      yield
    end
  end

  def full_name(owner, def_name = name)
    Call.full_name(owner, def_name)
  end

  def self.full_name(owner, method_name = name)
    case owner
    when Program, Nil
      method_name
    when owner.program.class_type
      # Class's instance_type is Object, not Class, so we cannot treat it like
      # other metaclasses
      "#{owner}##{method_name}"
    when .metaclass?
      "#{owner.instance_type}.#{method_name}"
    else
      "#{owner}##{method_name}"
    end
  end

  def signature(io : IO) : Nil
    io << full_name(obj.try(&.type)) << '('

    first = true
    args.each do |arg|
      case {arg_type = arg.type, arg}
      when {TupleInstanceType, Splat}
        next if arg_type.tuple_types.empty?
        io << ", " unless first
        arg_type.tuple_types.join(io, ", ")
      when {NamedTupleInstanceType, DoubleSplat}
        next if arg_type.entries.empty?
        io << ", " unless first
        arg_type.entries.join(io, ", ") do |entry|
          Symbol.quote_for_named_argument(io, entry.name)
          io << ": " << entry.type
        end
      else
        io << ", " unless first
        io << arg.type
      end
      first = false
    end

    if named_args = @named_args
      io << ", " unless first
      named_args.join(io, ", ") do |named_arg|
        Symbol.quote_for_named_argument(io, named_arg.name)
        io << ": " << named_arg.value.type
      end
    end

    io << ')'
  end

  private def colorize(obj)
    program.colorize(obj)
  end
end

class Crystal::Call
  def recalculate_lib_call(obj_type)
    replace_splats

    old_target_defs = @target_defs

    external = obj_type.lookup_first_def(name, false) as External?
    raise "undefined fun '#{name}' for #{obj_type}" unless external

    check_fun_args_size_match obj_type, external
    check_fun_out_args external
    return unless obj_and_args_types_set?

    check_fun_args_types_match obj_type, external

    obj_type.used = true
    external.used = true

    untyped_defs = [external] of Def
    @target_defs = untyped_defs

    self.unbind_from old_target_defs if old_target_defs
    self.bind_to untyped_defs

    if (parent_visitor = @parent_visitor) && (ptyped_def = parent_visitor.typed_def?) && untyped_defs.try(&.any?(&.raises))
      ptyped_def.raises = true
    end
  end

  def check_fun_args_size_match(obj_type, external)
    call_args_count = args.size
    all_args_count = external.args.size

    if external.varargs && call_args_count >= all_args_count
      return
    end

    required_args_count = external.args.count { |arg| !arg.default_value }

    return if required_args_count <= call_args_count <= all_args_count

    wrong_number_of_arguments "'#{full_name(obj_type)}'", args.size, external.args.size
  end

  def check_fun_out_args(untyped_def)
    untyped_def.args.each_with_index do |arg, i|
      call_arg = self.args[i]
      if call_arg.is_a?(Out)
        arg_type = arg.type
        if arg_type.is_a?(PointerInstanceType)
          if call_arg.exp.is_a?(Underscore)
            call_arg.exp.type = arg_type.element_type
          else
            var = parent_visitor.lookup_var_or_instance_var(call_arg.exp)
            var.bind_to Var.new("out", arg_type.element_type)
            call_arg.exp.bind_to var
            parent_visitor.bind_meta_var(call_arg.exp)
          end
        else
          call_arg.raise "argument \##{i + 1} to #{untyped_def.owner}.#{untyped_def.name} cannot be passed as 'out' because it is not a pointer"
        end
      end
    end

    # Check that there are no out args more then the number of arguments in the fun
    if untyped_def.varargs
      untyped_def.args.size.upto(self.args.size - 1) do |i|
        self_arg = self.args[i]
        if self_arg.is_a?(Out)
          self_arg.raise "can't use out at varargs position: declare the variable with `#{self_arg.exp} = uninitialized ...` and pass it with `pointerof(#{self_arg.exp})`"
        end
      end
    end
  end

  def check_fun_args_types_match(obj_type, typed_def)
    typed_def.args.each_with_index do |typed_def_arg, i|
      self_arg = self.args[i]
      check_fun_arg_type_matches(obj_type, self_arg, typed_def_arg, i)
    end

    # Need to call to_unsafe on variadic args too
    if typed_def.varargs
      typed_def.args.size.upto(self.args.size - 1) do |i|
        self_arg = self.args[i]
        self_arg_type = self_arg.type?
        if self_arg_type
          unless self_arg_type.nil_type? || self_arg_type.primitive_like?
            implicit_call = Conversions.try_to_unsafe(self_arg.clone, parent_visitor) do |ex|
              if Conversions.to_unsafe_lookup_failed?(ex)
                self_arg.raise "argument ##{i + 1} of '#{full_name(obj_type)}' is not a primitive type and no #{self_arg_type}#to_unsafe method found"
              else
                self_arg.raise ex.message, ex
              end
            end
            implicit_call_type = implicit_call.type?
            if implicit_call_type
              if implicit_call_type.primitive_like?
                self.args[i] = implicit_call
              else
                self_arg.raise "converted #{self_arg_type} invoking to_unsafe, but #{implicit_call_type} is not a primitive type"
              end
            else
              self_arg.raise "tried to convert #{self_arg_type} invoking to_unsafe, but can't deduce its type"
            end
          end
        else
          self_arg.raise "can't deduce argument type"
        end
      end
    end
  end

  def check_fun_arg_type_matches(obj_type, self_arg, typed_def_arg, index)
    expected_type = typed_def_arg.type
    actual_type = self_arg.type
    actual_type = mod.pointer_of(actual_type) if self_arg.is_a?(Out)
    return if actual_type.compatible_with?(expected_type)
    return if actual_type.is_implicitly_converted_in_c_to?(expected_type)

    unaliased_type = expected_type.remove_alias
    case unaliased_type
    when IntegerType
      return if convert_numeric_argument self_arg, unaliased_type, expected_type, actual_type, index
    when FloatType
      return if convert_numeric_argument self_arg, unaliased_type, expected_type, actual_type, index
    end

    implicit_call = Conversions.try_to_unsafe(self_arg.clone, parent_visitor) do |ex|
      if Conversions.to_unsafe_lookup_failed?(ex)
        arg_name = typed_def_arg.name.bytesize > 0 ? "'#{typed_def_arg.name}'" : "##{index + 1}"

        if expected_type.is_a?(FunInstanceType) &&
           actual_type.is_a?(FunInstanceType) &&
           expected_type.arg_types == actual_type.arg_types
          self_arg.raise "argument #{arg_name} of '#{full_name(obj_type)}' must be a function returning #{expected_type.return_type}, not #{actual_type.return_type}"
        else
          self_arg.raise "argument #{arg_name} of '#{full_name(obj_type)}' must be #{expected_type}, not #{actual_type}"
        end
      else
        self_arg.raise ex.message, ex
      end
    end

    implicit_call_type = implicit_call.type?
    if implicit_call_type
      if implicit_call_type.compatible_with?(expected_type)
        self.args[index] = implicit_call
      else
        arg_name = typed_def_arg.name.bytesize > 0 ? "'#{typed_def_arg.name}'" : "##{index + 1}"
        self_arg.raise "argument #{arg_name} of '#{full_name(obj_type)}' must be #{expected_type}, not #{actual_type} (nor #{implicit_call_type} returned by '#{actual_type}#to_unsafe')"
      end
    else
      self_arg.raise "tried to convert #{actual_type} to #{expected_type} invoking to_unsafe, but can't deduce its type"
    end
  end

  def check_not_lib_out_args
    args.find(&.is_a?(Out)).try &.raise "out can only be used with lib funs"
  end

  def convert_numeric_argument(self_arg, unaliased_type, expected_type, actual_type, index)
    if self_arg.is_a?(NumberLiteral)
      # TODO: check that the number literal fits, error otherwise

      # If converting from a float to integer, we need to remove the dot
      # so that later the codegen finds a correct value
      if unaliased_type.is_a?(IntegerType) && (dot_index = self_arg.value.index('.'))
        self_arg.value = self_arg.value[0...dot_index]
      end

      self_arg.kind = unaliased_type.kind
      self_arg.type = unaliased_type
      return true
    end

    convert_call = Conversions.numeric_argument(self_arg, self_arg.clone, parent_visitor, unaliased_type, expected_type, actual_type)
    return false unless convert_call

    self.args[index] = convert_call
    true
  end
end

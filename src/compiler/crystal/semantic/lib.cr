class Crystal::Call
  def recalculate_lib_call(obj_type)
    replace_splats

    old_target_defs = @target_defs

    external = obj_type.lookup_first_def(name, false) as External?
    raise "undefined fun '#{name}' for #{obj_type}" unless external

    check_fun_args_length_match obj_type, external
    check_fun_out_args external
    return unless obj_and_args_types_set?

    check_fun_args_types_match obj_type, external

    obj_type.used = true
    external.used = true

    untyped_defs = [external]
    @target_defs = untyped_defs

    self.unbind_from old_target_defs if old_target_defs
    self.bind_to untyped_defs
  end

  def check_fun_args_length_match(obj_type, external)
    call_args_count = args.length
    all_args_count = external.args.length

    if external.varargs && call_args_count >= all_args_count
      return
    end

    required_args_count = external.args.count { |arg| !arg.default_value }

    return if required_args_count <= call_args_count <= all_args_count

    raise "wrong number of arguments for '#{full_name(obj_type)}' (#{args.length} for #{external.args.length})"
  end

  def check_fun_out_args(untyped_def)
    untyped_def.args.each_with_index do |arg, i|
      call_arg = self.args[i]
      if call_arg.is_a?(Out)
        arg_type = arg.type
        if arg_type.is_a?(PointerInstanceType)
          var = parent_visitor.lookup_var_or_instance_var(call_arg.exp)
          var.bind_to Var.new("out", arg_type.element_type)
          call_arg.exp.bind_to var
          parent_visitor.bind_meta_var(call_arg.exp)
        else
          call_arg.raise "argument \##{i + 1} to #{untyped_def.owner}.#{untyped_def.name} cannot be passed as 'out' because it is not a pointer"
        end
      end
    end
  end

  def check_fun_args_types_match(obj_type, typed_def)
    typed_def.args.each_with_index do |typed_def_arg, i|
      expected_type = typed_def_arg.type
      self_arg = self.args[i]
      actual_type = self_arg.type
      actual_type = mod.pointer_of(actual_type) if self.args[i].is_a?(Out)
      unless actual_type.compatible_with?(expected_type) || actual_type.is_implicitly_converted_in_c_to?(expected_type)
        implicit_call = try_to_unsafe(self_arg) do |ex|
          if ex.message.not_nil!.includes?("undefined method 'to_unsafe'")
            arg_name = typed_def_arg.name.bytesize > 0 ? "'#{typed_def_arg.name}'" : "##{i + 1}"

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
            self.args[i] = implicit_call
          else
            arg_name = typed_def_arg.name.bytesize > 0 ? "'#{typed_def_arg.name}'" : "##{i + 1}"
            self_arg.raise "argument #{arg_name} of '#{full_name(obj_type)}' must be #{expected_type}, not #{actual_type} (nor #{implicit_call_type} returned by '#{actual_type}#to_unsafe')"
          end
        else
          self_arg.raise "tried to convert #{actual_type} to #{expected_type} invoking to_unsafe, but can't deduce its type"
        end
      end
    end

    # Need to call to_unsafe on variadic args too
    if typed_def.varargs
      typed_def.args.length.upto(self.args.length - 1) do |i|
        self_arg = self.args[i]
        self_arg_type = self_arg.type?
        if self_arg_type
          unless self_arg_type.nil_type? || self_arg_type.primitive_like?
            implicit_call = try_to_unsafe(self_arg) do |ex|
              if ex.message.not_nil!.includes?("undefined method 'to_unsafe'")
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

  def check_not_lib_out_args
    args.find(&.is_a?(Out)).try &.raise "out can only be used with lib funs"
  end

  def try_to_unsafe(self_arg)
    implicit_call = Call.new(self_arg.clone, "to_unsafe")
    begin
      implicit_call.accept parent_visitor
    rescue ex : TypeException
      yield ex
    end
    implicit_call
  end
end

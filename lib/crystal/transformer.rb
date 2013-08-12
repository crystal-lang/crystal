module Crystal
  class Transformer
    def before_transform(node)
    end

    def after_transform(node)
    end

    def transform_nop(node)
      node
    end

    def transform_expressions(node)
      exps = []
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end
        end
      end
      case exps.length
      when 0
        nil
      when 1
        exps[0]
      else
        node.expressions = exps
        node
      end
    end

    def transform_array_literal(node)
      transform_many node.elements
      node.of = node.of.transform(self) if node.of
      node
    end

    def transform_hash_literal(node)
      transform_many node.keys
      transform_many node.values
      node.of_key = node.of_key.transform(self) if node.of_key
      node.of_value = node.of_value.transform(self) if node.of_value
      node
    end

    def transform_class_def(node)
      node.body = node.body.transform(self)
      node.superclass = node.superclass.transform(self) if node.superclass
      node
    end

    def transform_module_def(node)
      node.body = node.body.transform(self)
      node
    end

    def transform_nil_literal(node)
      node
    end

    def transform_bool_literal(node)
      node
    end

    def transform_number_literal(node)
      node
    end

    def transform_int_literal(node)
      node
    end

    def transform_long_literal(node)
      node
    end

    def transform_float_literal(node)
      node
    end

    def transform_double_literal(node)
      node
    end

    def transform_char_literal(node)
      node
    end

    def transform_string_literal(node)
      node
    end

    def transform_string_interpolation(node)
      transform_many node.expressions
      node
    end

    def transform_symbol_literal(node)
      node
    end

    def transform_range_literal(node)
      node.from = node.from.transform(self)
      node.to = node.to.transform(self)
      node
    end

    def transform_regexp_literal(node)
      node
    end

    def transform_def(node)
      transform_many node.args
      node.body = node.body.transform(self)
      node.receiver = node.receiver.transform(self) if node.receiver
      node.block_arg = node.block_arg.transform(self) if node.block_arg
      node
    end

    def transform_var(node)
      node
    end

    def transform_global(node)
      node
    end

    def transform_arg(node)
      node.default_value = node.default_value.transform(self) if node.default_value
      node.type_restriction = node.type_restriction.transform(self) if node.type_restriction.is_a?(ASTNode)
      node
    end

    def transform_block_arg(node)
      transform_many node.inputs
      node.output = node.output.transform(self) if node.output
      node
    end

    def transform_ident(node)
      node
    end

    def transform_ident_union(node)
      transform_many node.idents
      node
    end

    def transform_self_type(node)
      node
    end

    def transform_instance_var(node)
      node
    end

    def transform_and(node)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)
      node
    end

    def transform_or(node)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)
      node
    end

    def transform_simple_or(node)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)
      node
    end

    def transform_call(node)
      node.obj = node.obj.transform(self) if node.obj
      transform_many node.args
      node.block = node.block.transform(self) if node.block
      node
    end

    def transform_if(node)
      node.cond = node.cond.transform(self)
      node.then = node.then.transform(self)
      node.else = node.else.transform(self)
      node
    end

    def transform_unless(node)
      node.cond = node.cond.transform(self)
      node.then = node.then.transform(self)
      node.else = node.else.transform(self)
      node
    end

    def transform_assign(node)
      node.target = node.target.transform(self)
      node.value = node.value.transform(self)
      node
    end

    def transform_multi_assign(node)
      transform_many node.targets
      transform_many node.values
      node
    end

    def transform_while(node)
      node.cond = node.cond.transform(self)
      node.body = node.body.transform(self)
      node
    end

    def transform_block(node)
      transform_many node.args
      node.body = node.body.transform(self)
      node
    end

    def transform_return(node)
      transform_many node.exps
      node
    end

    def transform_break(node)
      transform_many node.exps
      node
    end

    def transform_next(node)
      transform_many node.exps
      node
    end

    def transform_yield(node)
      node.scope = node.scope.transform(self) if node.scope
      transform_many node.exps
      node
    end

    def transform_lib_def(node)
      node
    end

    def transform_fun_def(node)
      node
    end

    def transform_fun_def_arg(node)
      node
    end

    def transform_type_def(node)
      node
    end

    def transform_struct_def(node)
      node
    end

    def transform_include(node)
      node.name = node.name.transform(self)
      node
    end

    def transform_macro(node)
      transform_many node.args
      node.body = node.body.transform(self)
      node.receiver = node.receiver.transform(self) if node.receiver
      node.block_arg = node.block_arg.transform(self) if node.block_arg
      node
    end

    def transform_pointer_of(node)
      node.var = node.var.transform(self)
      node
    end

    def transform_is_a(node)
      node.obj = node.obj.transform(self)
      node.const = node.const.transform(self)
      node
    end

    def transform_require(node)
      node
    end

    def transform_case(node)
      node.cond = node.cond.transform(self)
      transform_many node.whens
      node.else = node.else.transform(self) if node.else
      node
    end

    def transform_when(node)
      transform_many node.conds
      node.body = node.body.transform(self)
      node
    end

    def transform_new_generic_class(node)
      node.name = node.name.transform(self)
      transform_many node.type_vars
      node
    end

    def transform_declare_var(node)
      node.declared_type = node.declared_type.transform(self)
      node
    end

    def transform_exception_handler(node)
      node.body = node.body.transform(self)
      transform_many node.rescues
      node.ensure = node.ensure.transform(self) if node.ensure
      node
    end

    def transform_rescue(node)
      node.body = node.body.transform(self)
      transform_many node.types
      node
    end

    def transform_type_merge(node)
      transform_many node.expressions
      node
    end

    def transform_many(exps)
      exps.map! { |exp| exp.transform(self) } if exps
    end

    def transform_primitive_body(node)
      node
    end

    def transform_pointer_malloc(node)
      node
    end

    def transform_pointer_null(node)
      node
    end

    def transform_pointer_malloc_with_value(node)
      node
    end

    def transform_pointer_get_value(node)
      node
    end

    def transform_pointer_set_value(node)
      node
    end

    def transform_pointer_add(node)
      node
    end

    def transform_pointer_realloc(node)
      node
    end

    def transform_pointer_cast(node)
      node
    end

    def transform_allocate(node)
      node
    end

    def transform_struct_alloc(node)
      node
    end

    def transform_struct_set(node)
      node
    end

    def transform_struct_get(node)
      node
    end

    def transform_union_alloc(node)
      node
    end

    def transform_union_set(node)
      node
    end

    def transform_union_get(node)
      node
    end

    def transform_argc(node)
      node
    end

    def transform_argv(node)
      node
    end

    def transform_nil_pointer(node)
      node
    end

    def transform_class_method(node)
      node
    end
  end
end

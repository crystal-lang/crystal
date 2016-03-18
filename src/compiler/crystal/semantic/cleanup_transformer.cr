require "../syntax/ast"
require "../syntax/transformer"
require "../types"

module Crystal
  class Program
    def cleanup(node)
      node = node.transform(CleanupTransformer.new(self))
      puts node if ENV["AFTER"]? == "1"
      node
    end

    def cleanup_types
      transformer = CleanupTransformer.new(self)
      after_inference_types.each do |type|
        cleanup_type type, transformer
      end
    end

    def cleanup_type(type, transformer)
      case type
      when GenericClassInstanceType
        cleanup_single_type(type, transformer)
      when GenericClassType
        type.generic_types.each_value do |instance|
          cleanup_type instance, transformer
        end
      when ClassType
        cleanup_single_type(type, transformer)
      end
    end

    def cleanup_single_type(type, transformer)
      type.instance_vars_initializers.try &.each do |initializer|
        initializer.value = initializer.value.transform(transformer)
      end
    end
  end

  # This visitor runs at the end and does some simplifications to the resulting AST node.
  #
  # For example, it rewrites and `if true; 1; else; 2; end` to a single `1`. It does
  # so for other "always true conditions", such as `x.is_a?(Foo)` where `x` can only
  # be of type `Foo`. These simplications are needed because the codegen would have no
  # idea on how to generate code for unreachable branches, because they have no type,
  # and for now the codegen only deals with typed nodes.
  class CleanupTransformer < Transformer
    @program : Program
    @transformed : Set(UInt64)
    @def_nest_count : Int32
    @last_is_truthy : Bool
    @last_is_falsey : Bool
    @const_being_initialized : Path?

    def initialize(@program)
      @transformed = Set(typeof(object_id)).new
      @def_nest_count = 0
      @last_is_truthy = false
      @last_is_falsey = false
    end

    def after_transform(node)
      case node
      when And, Or, If, RespondsTo, IsA, Assign
        # Nothing
      when BoolLiteral
        if node.value
          @last_is_truthy = true
        else
          @last_is_falsey = true
        end
      when NilLiteral
        @last_is_falsey = true
      else
        reset_last_status
      end
    end

    def reset_last_status
      @last_is_truthy = false
      @last_is_falsey = false
    end

    def transform(node : Def)
      node.runtime_initializers.try &.map! &.transform self
      node
    end

    def transform(node : ClassDef)
      super

      node.runtime_initializers.try &.map! &.transform self
      node
    end

    def transform(node : Include)
      node.runtime_initializers.try &.map! &.transform self
      node
    end

    def transform(node : Extend)
      node.runtime_initializers.try &.map! &.transform self
      node
    end

    def transform(node : Expressions)
      exps = [] of ASTNode

      node.expressions.each_with_index do |exp, i|
        new_exp = exp.transform(self)

        # We collect the transformed expressions, recursively,
        # by flattening them. We stop collecting when there's
        # a NoReturn expression, next, break or return.
        break if flatten_collect(new_exp, exps)
      end

      if exps.empty?
        nop = Nop.new
        nop.set_type(@program.nil)
        exps << nop
      end

      node.expressions = exps
      rebind_node node, exps.last
      node
    end

    def flatten_collect(exp, exps)
      if exp.is_a?(Expressions)
        exp.expressions.each do |subexp|
          return true if flatten_collect(subexp, exps)
        end
      else
        exps << exp
        if exp.is_a?(Break) || exp.is_a?(Next) || exp.is_a?(Return) || exp.no_returns?
          return true
        end
      end
      false
    end

    def transform(node : ExpandableNode)
      if expanded = node.expanded
        return expanded.transform(self)
      end
      node
    end

    def transform(node : Assign)
      reset_last_status

      target = node.target

      # This is the case of an instance variable initializer
      if @def_nest_count == 0 && target.is_a?(InstanceVar)
        return Nop.new
      end

      if target.is_a?(Path)
        const = target.target_const.not_nil!
        if const.used
          @const_being_initialized = target
        else
          return node
        end
      end

      node.value = node.value.transform self

      unless node.value.type?
        return untyped_expression node
      end

      if target.is_a?(Path)
        const = const.not_nil!
        const.initialized = true
        const.value = const.value.transform self
        @const_being_initialized = nil
      end

      if target.is_a?(Global)
        @program.initialized_global_vars.add target.name
      end

      if node.target == node.value
        node.raise "expression has no effect"
      end

      # We don't want to transform constant assignments into no return
      unless node.target.is_a?(Path)
        if node.value.type?.try &.no_return?
          rebind_node node, node.value
          return node.value
        end
      end

      node
    end

    def transform(node : Path)
      if target_const = node.target_const
        if target_const.used && !target_const.initialized?
          value = target_const.value
          if (const_node = @const_being_initialized) && !simple_constant?(value)
            const_being_initialized = const_node.target_const.not_nil!
            const_node.raise "constant #{const_being_initialized} requires initialization of #{target_const}, \
                                        which is initialized later. Initialize #{target_const} before #{const_being_initialized}"
          end
        end
      end

      super
    end

    def transform(node : Global)
      if const_node = @const_being_initialized
        const_being_initialized = const_node.target_const.not_nil!

        if !@program.initialized_global_vars.includes?(node.name)
          global_var = @program.global_vars[node.name]
          if global_var.type?.try { |t| !t.includes_type?(@program.nil) }
            const_node.raise "constant #{const_being_initialized} requires initialization of #{node}, \
                                        which is initialized later. Initialize #{node} before #{const_being_initialized}"
          end
        end
      end

      node
    end

    def transform(node : EnumDef)
      super

      if node.created_new_type
        node.resolved_type.types.each_value do |const|
          (const as Const).initialized = true
        end
      end

      node
    end

    def transform(node : Call)
      if expanded = node.expanded
        return expanded.transform self
      end

      # Need to transform these manually because node.block doesn't
      # need to be transformed if it has a fun_literal
      # ~~~
      if node_obj = node.obj
        node.obj = node_obj.transform(self)
      end
      transform_many node.args

      if (node_block = node.block) && !node_block.fun_literal
        node.block = node_block.transform(self)
      end

      if node_block_arg = node.block_arg
        node.block_arg = node_block_arg.transform(self)
      end

      if named_args = node.named_args
        named_args.map! { |named_arg| named_arg.transform(self) as NamedArgument }
      end
      # ~~~

      obj = node.obj
      obj_type = obj.try &.type?
      block = node.block

      if !node.type? && obj && obj_type && obj_type.module?
        return untyped_expression(node, "`#{node}` has no type")
      end

      if block && (fun_literal = block.fun_literal)
        block.fun_literal = fun_literal.transform(self)
      end

      # Check if we have an untyped expression in this call, or an expression
      # whose type was never allocated. Replace it with raise.
      if (obj && !obj_type)
        return untyped_expression(node, "`#{obj}` has no type")
      end

      if obj && !obj.type.allocated?
        return untyped_expression(node, "#{obj.type} in `#{obj}` was never instantiated")
      end

      node.args.each do |arg|
        unless arg.type?
          return untyped_expression(node, "`#{arg}` has no type")
        end

        unless arg.type.allocated?
          return untyped_expression(node, "#{arg.type} in `#{arg}` was never instantiated")
        end
      end

      # Check if the block has its type freezed and it doesn't match the current type
      if block && (freeze_type = block.freeze_type) && (block_type = block.type?)
        unless block_type.implements?(freeze_type)
          freeze_type = freeze_type.base_type if freeze_type.is_a?(VirtualType)
          node.raise "expected block to return #{freeze_type}, not #{block_type}"
        end
      end

      # If any expression is no-return, replace the call with its expressions up to
      # the one that no returns.
      if (obj.try &.type?.try &.no_return?) || node.args.any? &.type?.try &.no_return?
        call_exps = [] of ASTNode
        call_exps << obj if obj
        unless obj.try &.type?.try &.no_return?
          node.args.each do |arg|
            call_exps << arg
            break if arg.type?.try &.no_return?
          end
        end
        exps = Expressions.new(call_exps)
        exps.set_type(call_exps.last.type?) unless call_exps.empty?
        return exps
      end

      if target_defs = node.target_defs
        changed = false
        allocated_defs = [] of Def

        if target_defs.size == 1
          if target_defs[0].is_a?(External)
            check_args_are_not_closure node, "can't send closure to C function"
          elsif obj_type.is_a?(CStructType) && node.name.ends_with?('=')
            check_args_are_not_closure node, "can't set closure as C struct member"
          elsif obj_type.is_a?(CUnionType) && node.name.ends_with?('=')
            check_args_are_not_closure node, "can't set closure as C union member"
          end
        end

        target_defs.each do |target_def|
          allocated = target_def.owner.allocated? && target_def.args.all? &.type.allocated?
          if allocated
            allocated_defs << target_def

            unless @transformed.includes?(target_def.object_id)
              @transformed.add(target_def.object_id)

              node.bubbling_exception do
                old_body = target_def.body
                old_type = target_def.body.type?

                @def_nest_count += 1
                target_def.body = target_def.body.transform(self)
                @def_nest_count -= 1

                new_type = target_def.body.type?

                # It can happen that the body of the function changed, and as
                # a result the type changed. In that case we need to rebind the
                # def to the new body, unbinding it from the prevoius one.
                if new_type != old_type
                  target_def.unbind_from old_body
                  target_def.bind_to target_def.body
                end
              end
            end
          else
            changed = true
          end
        end

        if changed
          node.unbind_from node.target_defs
          node.target_defs = allocated_defs
          node.bind_to allocated_defs
        end

        if node.target_defs.not_nil!.empty?
          exps = [] of ASTNode
          if obj = node.obj
            exps.push obj
          end
          node.args.each { |arg| exps.push arg }
          call_exps = Expressions.from exps
          call_exps.set_type(exps.last.type?) unless exps.empty?
          return call_exps
        end
      end

      # Convert named arguments to regular arguments, because intermediate
      # defs with the needed number of arguments are already defined.
      if named_args = node.named_args
        named_args.each do |named_arg|
          node.args << named_arg.value
        end
        node.named_args = nil
      end

      node.replace_splats

      # check_comparison_of_unsigned_integer_with_zero_or_negative_literal(node)

      node
    end

    def number_lines(source)
      source.lines.to_s_with_line_numbers
    end

    class ClosuredVarsCollector < Visitor
      getter vars : Array(ASTNode)
      @a_def : Def

      def self.collect(a_def)
        visitor = new a_def
        a_def.accept visitor
        visitor.vars
      end

      def initialize(@a_def)
        @vars = [] of ASTNode
      end

      def visit(node : Var)
        if @a_def.vars.try &.[node.name].closured
          @vars << node
        end
      end

      def visit(node : InstanceVar)
        @vars << node
      end

      def visit(node : ASTNode)
        true
      end
    end

    def check_args_are_not_closure(node, message)
      node.args.each do |arg|
        case arg
        when FunLiteral
          if arg.def.closure
            vars = ClosuredVarsCollector.collect arg.def
            unless vars.empty?
              message += " (closured vars: #{vars.join ", "})"
            end

            arg.raise message
          end
        when FunPointer
          if arg.obj.try &.type?.try &.passed_as_self?
            arg.raise "#{message} (closured vars: self)"
          end

          owner = arg.call.target_def.owner
          if owner.passed_as_self?
            arg.raise "#{message} (closured vars: self)"
          end
        end
      end
    end

    def transform(node : FunPointer)
      super

      if call = node.call?
        result = call.transform(self)

        # If the transform didn't end up in a Call, it means the
        # call will never be executed.
        if result.is_a?(Call)
          node.call = result
        end
      end

      node
    end

    def transform(node : FunLiteral)
      body = node.def.body
      if node.def.no_returns? && !body.type?
        node.def.body = untyped_expression(body)
        rebind_node node.def, node.def.body
        node.update
      else
        node.def.body = node.def.body.transform(self)
      end
      node
    end

    def untyped_expression(node, msg = nil)
      ex_msg = String.build do |str|
        str << "can't execute `"
        str << node
        str << "`"
        str << " at "
        str << node.location
        if msg
          str << ": "
          str << msg
        end
      end

      build_raise ex_msg
    end

    def build_raise(msg)
      call = Call.global("raise", StringLiteral.new(msg))
      call.accept MainVisitor.new(@program)
      call
    end

    def transform(node : Yield)
      if expanded = node.expanded
        return expanded.transform(self)
      end

      super

      # If the yield has a no-return expression, the yield never happens:
      # replace it with a series of expressions up to the one that no-returns.
      no_return_index = node.exps.index &.no_returns?
      if no_return_index
        exps = Expressions.new(node.exps[0, no_return_index + 1])
        exps.bind_to(exps.expressions.last)
        return exps
      end

      node
    end

    # def check_comparison_of_unsigned_integer_with_zero_or_negative_literal(node)
    #   if (node.name == :< || node.name == :<=) && node.obj && node.obj.type && node.obj.type.integer? && node.obj.type.unsigned?
    #     arg = node.args[0]
    #     if arg.is_a?(NumberLiteral) && arg.integer? && arg.value.to_i <= 0
    #       node.raise "'#{node.name}' comparison of unsigned integer with zero or negative literal will always be false"
    #     end
    #   end

    #   if (node.name == :> || node.name == :>=) && node.obj && node.obj.type && node.obj.is_a?(NumberLiteral) && node.obj.integer? && node.obj.value.to_i <= 0
    #     arg = node.args[0]
    #     if arg.type.integer? && arg.type.unsigned?
    #       node.raise "'#{node.name}' comparison of unsigned integer with zero or negative literal will always be false"
    #     end
    #   end
    # end

    def transform(node : While)
      super

      # If the condition is a NoReturn, just replace the whole
      # while with it, since the body will never be executed
      if node.cond.no_returns?
        return node.cond
      end

      node
    end

    def transform(node : If)
      node.cond = node.cond.transform(self)

      node_cond = node.cond
      cond_is_truthy, cond_is_falsey = @last_is_truthy, @last_is_falsey
      reset_last_status

      if node_cond.no_returns?
        return node_cond
      end

      if node_cond.true_literal?
        node.then = node.then.transform(self)
        rebind_node node, node.then
        return node.then
      end

      if node_cond.false_literal?
        node.else = node.else.transform(self)
        rebind_node node, node.else
        return node.else
      end

      if (cond_type = node_cond.type?) && cond_type.nil_type?
        node.else = node.else.transform(self)
        return replace_if_with_branch(node, node.else)
      end

      if cond_is_truthy
        node.then = node.then.transform(self)
        return replace_if_with_branch(node, node.then)
      end

      if cond_is_falsey
        node.else = node.else.transform(self)
        return replace_if_with_branch(node, node.else)
      end

      node.then = node.then.transform(self)
      then_is_truthy, then_is_falsey = @last_is_truthy, @last_is_falsey

      node.else = node.else.transform(self)

      reset_last_status

      if node.binary == :and
        @last_is_truthy = cond_is_truthy && then_is_truthy
        @last_is_falsey = cond_is_falsey || then_is_falsey
      end

      node
    end

    def replace_if_with_branch(node, branch)
      exp_nodes = [node.cond] of ASTNode
      exp_nodes << branch

      exp = Expressions.new(exp_nodes)
      if branch
        exp.bind_to branch
        rebind_node node, branch
      else
        exp.bind_to @program.nil_var
      end
      exp
    end

    def transform(node : IsA)
      super
      reset_last_status
      if replacement = node.syntax_replacement
        replacement.transform(self)
      else
        transform_is_a_or_responds_to node, &.filter_by(node.const.type)
      end
    end

    def transform(node : RespondsTo)
      super
      reset_last_status
      transform_is_a_or_responds_to node, &.filter_by_responds_to(node.name)
    end

    def transform_is_a_or_responds_to(node)
      obj = node.obj

      if obj_type = obj.type?
        filtered_type = yield obj_type

        if obj_type == filtered_type
          @last_is_truthy = true
          if var?(obj)
            return true_literal
          else
            exps = Expressions.new([obj, true_literal] of ASTNode)
            exps.type = @program.bool
            return exps
          end
        end

        unless filtered_type
          @last_is_falsey = true
          if var?(obj)
            return false_literal
          else
            exps = Expressions.new([obj, false_literal] of ASTNode)
            exps.type = @program.bool
            return exps
          end
        end
      end

      node
    end

    def var?(node)
      case node
      when Var, InstanceVar, ClassVar, Global
        true
      else
        false
      end
    end

    def transform(node : Cast)
      node = super

      obj_type = node.obj.type?
      return node unless obj_type

      to_type = node.to.type

      if to_type == @program.object
        node.raise "useless cast"
      end

      if to_type.pointer?
        if obj_type.pointer? || obj_type.reference_like?
          return node
        else
          node.raise "can't cast #{obj_type} to #{to_type}"
        end
      end

      if obj_type.pointer?
        unless to_type.pointer? || to_type.reference_like?
          node.raise "can't cast #{obj_type} to #{to_type}"
        end
      elsif obj_type.no_return?
        node.type = @program.no_return
      else
        resulting_type = obj_type.filter_by(to_type)
        unless resulting_type
          node.raise "can't cast #{obj_type} to #{to_type}"
        end

        unless to_type.allocated?
          return build_raise "can't cast to #{to_type} because it was never instantiated"
        end
      end

      node
    end

    def transform(node : FunDef)
      node_body = node.body
      return node unless node_body

      node.body = node_body.transform(self)

      if node_external = node.external
        node_external.body = node_external.body.transform(self)
      end
      node
    end

    def transform(node : ExceptionHandler)
      node = super

      if node.body.no_returns?
        node.else = nil
      end

      if node_rescues = node.rescues
        new_rescues = [] of Rescue

        node_rescues.each do |a_rescue|
          if !a_rescue.type? || a_rescue.type.allocated?
            new_rescues << a_rescue
          end
        end

        if new_rescues.empty?
          if node.ensure
            node.rescues = nil
          else
            rebind_node node, node.body
            return node.body
          end
        else
          node.rescues = new_rescues
        end
      end

      node
    end

    def transform(node : InstanceSizeOf)
      exp_type = node.exp.type?

      if exp_type
        instance_type = exp_type.instance_type
        unless instance_type.class?
          node.exp.raise "#{instance_type} is not a class, it's a #{instance_type.type_desc}"
        end
      end

      node
    end

    def transform(node : TupleLiteral)
      super
      node.update
      node
    end

    def transform(node : StructDef)
      type = node.type as CStructType
      if type.vars.empty?
        node.raise "empty structs are disallowed"
      end
      node
    end

    def transform(node : UnionDef)
      type = node.type as CUnionType
      if type.vars.empty?
        node.raise "empty unions are disallowed"
      end
      node
    end

    def transform(node : Primitive)
      if extra = node.extra
        node.extra = extra.transform(self)
      end
      node
    end

    def rebind_node(node, dependency)
      node.unbind_from node.dependencies?
      if dependency
        if dependency.type?
          node.bind_to dependency
        else
          node.set_type(nil)
        end
      else
        node.bind_to @program.nil_var
      end
    end

    @false_literal : BoolLiteral?

    def false_literal
      @false_literal ||= begin
        false_literal = BoolLiteral.new(false)
        false_literal.set_type(@program.bool)
        false_literal
      end
    end

    @true_literal : BoolLiteral?

    def true_literal
      @true_literal ||= begin
        true_literal = BoolLiteral.new(true)
        true_literal.set_type(@program.bool)
        true_literal
      end
    end

    def simple_constant?(node)
      simple_constant?(node, [] of Const)
    end

    def simple_constant?(node, consts)
      case node
      when NilLiteral, BoolLiteral, CharLiteral, NumberLiteral, StringLiteral
        return true
      when Call
        obj = node.obj
        return false unless obj

        case node.args.size
        when 0
          case node.name
          when "+", "-", "~"
            return simple_constant?(obj, consts)
          end
        when 1
          case node.name
          when "+", "-", "*", "/", "&", "|"
            return simple_constant?(obj, consts) && simple_constant?(node.args.first, consts)
          end
        end
      when Path
        if target_const = node.target_const
          return false if consts.includes?(target_const)

          consts << target_const
          return simple_constant?(target_const.value, consts)
        end
      end

      false
    end
  end
end

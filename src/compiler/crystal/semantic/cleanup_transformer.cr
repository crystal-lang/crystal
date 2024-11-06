require "../syntax/ast"
require "../syntax/transformer"
require "../types"

module Crystal
  class Program
    getter(cleanup_transformer : CleanupTransformer) do
      CleanupTransformer.new(self)
    end

    def cleanup(node, inside_def = false)
      transformer = self.cleanup_transformer
      transformer.inside_def! if inside_def
      node = node.transform(transformer)
      puts node if ENV["AFTER"]? == "1"
      node
    end

    def cleanup_types
      transformer = self.cleanup_transformer

      after_inference_types.each do |type|
        cleanup_type type, transformer
      end

      self.class_var_initializers.each do |initializer|
        initializer.node = initializer.node.transform(transformer)
      end
    end

    def cleanup_type(type, transformer)
      case type
      when GenericClassInstanceType
        cleanup_single_type(type, transformer)
      when GenericClassType
        type.each_instantiated_type do |instance|
          cleanup_type instance, transformer
        end
      when ClassType
        cleanup_single_type(type, transformer)
      else
        # no need to clean up
      end
    end

    def cleanup_single_type(type, transformer)
      type.instance_vars_initializers.try &.each do |initializer|
        initializer.value = initializer.value.transform(transformer)
      end
    end

    def cleanup_files
      tempfiles.each do |tempfile|
        File.delete?(tempfile)
      end
    end
  end

  # This visitor runs at the end and does some simplifications to the resulting AST node.
  #
  # For example, it rewrites and `if true; 1; else; 2; end` to a single `1`. It does
  # so for other "always true conditions", such as `x.is_a?(Foo)` where `x` can only
  # be of type `Foo`. These simplifications are needed because the codegen would have no
  # idea on how to generate code for unreachable branches, because they have no type,
  # and for now the codegen only deals with typed nodes.
  class CleanupTransformer < Transformer
    @transformed : Set(Def)

    # The current method we are processing
    @current_def : Def?

    def initialize(@program : Program)
      @transformed = Set(Def).new.compare_by_identity
      @exhaustiveness_checker = ExhaustivenessChecker.new(@program)
      @def_nest_count = 0
      @last_is_truthy = false
      @last_is_falsey = false
    end

    def inside_def!
      @def_nest_count += 1
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
      when Not
        if @last_is_truthy
          @last_is_falsey = true
          @last_is_truthy = false
        elsif @last_is_falsey
          @last_is_truthy = true
          @last_is_falsey = false
        else
          reset_last_status
        end
      when NilLiteral
        @last_is_falsey = true
      when Nop
        @last_is_falsey = true
      else
        if node.type?.try &.nil_type?
          @last_is_falsey = true
          @last_is_truthy = false
        else
          reset_last_status
        end
      end
    end

    def reset_last_status
      @last_is_truthy = false
      @last_is_falsey = false
    end

    def compute_last_truthiness(&)
      reset_last_status
      yield
      {@last_is_truthy, @last_is_falsey}
    end

    def transform(node : AnnotationDef)
      @program.check_call_to_deprecated_annotation node

      node
    end

    def transform(node : Def)
      node.hook_expansions.try &.map! &.transform self
      node
    end

    def transform(node : ClassDef)
      super

      node.hook_expansions.try &.map! &.transform self
      node
    end

    def transform(node : Include)
      node.hook_expansions.try &.map! &.transform self
      node
    end

    def transform(node : Extend)
      node.hook_expansions.try &.map! &.transform self
      node
    end

    def transform(node : Expressions)
      if exp = node.single_expression?
        return exp.transform(self)
      end

      exps = [] of ASTNode

      node.expressions.each_with_index do |exp, i|
        new_exp = exp.transform(self)

        # We collect the transformed expressions, recursively,
        # by flattening them. We stop collecting when there's
        # a NoReturn expression, next, break or return.
        break if flatten_collect(new_exp, exps)
      end

      node.expressions = exps
      node
    end

    def flatten_collect(exp, exps)
      exp = exp.single_expression
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

    def transform(node : Case)
      @exhaustiveness_checker.check(node) if node.exhaustive?

      if expanded = node.expanded
        if node.exhaustive?
          replace_unreachable_if_needed(node, expanded)
        end

        return expanded.transform(self)
      end

      node
    end

    # If any of the types checked in `case` is an enum, it can happen that
    # the unreachable can be reached by doing `SomeEnum.new(some_value)`.
    # In that case we replace the Unreachable node with `raise "..."`.
    # In the future we should disallow creating such values.
    def replace_unreachable_if_needed(node, expanded)
      cond = node.cond
      return unless cond

      if cond.is_a?(TupleLiteral)
        return unless cond.elements.all?(&.type?) &&
                      cond.elements.any? { |element| has_enum_type?(element.type) }
      else
        cond_type = cond.type?
        return unless cond_type && has_enum_type?(cond_type)
      end

      an_if = find_unreachable_parent(expanded)
      unless an_if
        node.raise "BUG: expected to find Unreachable node"
      end

      an_if.else = build_raise("Unhandled case: enum value outside of defined enum members", node)
    end

    def has_enum_type?(type)
      if type.is_a?(UnionType)
        type.union_types.any?(EnumType)
      else
        type.is_a?(EnumType)
      end
    end

    def find_unreachable_parent(expanded)
      # An expanded case is either a series of if/else, or
      # a bunch of assignments and then a series of if/else.
      # The if/else chain always comes last.
      if expanded.is_a?(Expressions)
        expanded = expanded.expressions.last
      end

      while expanded.is_a?(If)
        if an_else = expanded.else
          if an_else.is_a?(Unreachable)
            return expanded
          else
            expanded = an_else
          end
        end
      end
      nil
    end

    def transform(node : StringInterpolation)
      # See if we can solve all the pieces to string literals.
      # If that's the case, we can replace the entire interpolation
      # with a single string literal.
      pieces = node.expressions.dup
      solve_string_interpolation_expressions(pieces)

      if pieces.all?(StringLiteral)
        string = pieces.join(&.as(StringLiteral).value)
        string_literal = StringLiteral.new(string).at(node)
        string_literal.type = @program.string
        return string_literal
      end

      if expanded = node.expanded
        return expanded.transform(self)
      end
      node
    end

    private def solve_string_interpolation_expressions(pieces : Array(ASTNode))
      pieces.each_with_index do |piece, i|
        replacement = solve_string_interpolation_expression(piece)
        next unless replacement

        pieces[i] = replacement
      end
    end

    private def solve_string_interpolation_expression(piece : ASTNode) : StringLiteral?
      if piece.is_a?(ExpandableNode)
        if expanded = piece.expanded
          return solve_string_interpolation_expression(expanded)
        end
      end

      case piece
      when Path
        if target_const = piece.target_const
          return solve_string_interpolation_expression(target_const.value)
        end
      when StringLiteral
        return piece
      end

      nil
    end

    def transform(node : ExpandableNode)
      if expanded = node.expanded
        return expanded.transform(self)
      end
      node
    end

    def transform(node : Assign)
      reset_last_status

      if void_lib_call?(node.value)
        node.value.raise "assigning Void return value of lib fun call has no effect"
      end

      target = node.target

      # Ignore class var initializers
      if target.is_a?(ClassVar) && !target.type?
        return node
      end

      # This is the case of an instance variable initializer
      if @def_nest_count == 0 && target.is_a?(InstanceVar)
        return Nop.new
      end

      if target.is_a?(Path)
        const = target.target_const.not_nil!
        return node if !const.used? || const.cleaned_up?

        unless const.value.type?
          node.raise "can't infer type of constant #{const} (maybe the constant refers to itself?)"
        end

        if const.value.type.no_return?
          node.raise "constant #{const} has illegal type NoReturn"
        end
      end

      node.value = node.value.transform self

      unless node.value.type?
        return untyped_expression node
      end

      if target.is_a?(Path)
        const = const.not_nil!
        const.value = const.value.transform self
        const.cleaned_up = true
      end

      if target == node.value &&
         # This condition is because the interpreter will generate expressions
         # like `$~ = $~` in multidispatches, and that's fine.
         !(target.is_a?(Var) && target.special_var?)
        node.raise "expression has no effect"
      end

      # We don't want to transform constant assignments into no return
      unless node.target.is_a?(Path)
        if node.value.type?.try &.no_return?
          return node.value
        end
      end

      node
    end

    def transform(node : MultiAssign)
      expanded = node.expanded

      if node.values.size == 1 && expanded
        # the expanded node always starts with `temp = {{ node.values[0] }}`;
        # `temp_assign` is this whole Assign node and its deduced type is same
        # as the original RHS's type
        temp_assign = expanded.as(Expressions).expressions.first
        type = temp_assign.type
        target_count = node.targets.size
        has_strict_multi_assign = @program.has_flag?("strict_multi_assign")

        # disallows `a, *b, c = {0 => "x", 1 => "y", 2 => "z"}`, as `Hash` is
        # not `Indexable`
        # also disallows `a, b, c = ...` if the strict flag is set
        if node.targets.any?(Splat) || has_strict_multi_assign
          unless type.implements?(@program.indexable)
            node.values.first.raise "right-hand side of one-to-many assignment must be an Indexable, not #{type}"
          end
        end

        if has_strict_multi_assign
          case type
          when UnionType
            sizes = type.union_types.map { |union_type| constant_size(union_type) }
            if sizes.none? &.in?(target_count, nil)
              node.values.first.raise "cannot assign #{type} to #{target_count} targets"
            end
          else
            if size = constant_size(type)
              unless size == target_count
                node.values.first.raise "cannot assign #{type} to #{target_count} targets"
              end
            end
          end
        end
      end

      if expanded
        return expanded.transform self
      end

      node
    end

    private def constant_size(type)
      case type
      when TupleInstanceType
        type.size
      end
    end

    def transform(node : Path)
      if const = node.target_const
        @program.check_deprecated_constant(const, node)

        # Some constants might not have been cleaned up at this point because
        # they don't have an explicit `Assign` node. One example is regex
        # literals: a constant is created for them, but there's no `Assign` node.
        if const.used? && !const.cleaned_up?
          const.value = const.value.transform self
          const.cleaned_up = true
        end
      end

      node
    end

    private def void_lib_call?(node)
      return false unless node.is_a?(Call)

      obj = node.obj
      return false unless obj.is_a?(Path)

      type = obj.type?
      return false unless type.is_a?(LibType)

      !!node.type?.try &.nil_type?
    end

    def transform(node : Global)
      if expanded = node.expanded
        return expanded.transform self
      end

      node
    end

    def transform(node : Call)
      if expanded = node.expanded
        return expanded.transform self
      end

      unless @current_def.try(&.annotation(@program.deprecated_annotation))
        @program.check_call_to_deprecated_method(node)
      end

      # Need to transform these manually because node.block doesn't
      # need to be transformed if it has a fun_literal
      # ~~~
      if node_obj = node.obj
        node.obj = node_obj.transform(self)
      end
      transform_many node.args

      if (node_block = node.block) && !node_block.fun_literal
        # TODO: if the block isn't used in any of the target defs we could
        # avoid transforming it, because it probably isn't typed **at all**
        node.block = node_block.transform(self)
      end

      if node_block_arg = node.block_arg
        node.block_arg = node_block_arg.transform(self)
      end

      if named_args = node.named_args
        named_args.map! { |named_arg| named_arg.transform(self).as(NamedArgument) }
      end
      # ~~~

      node.args.each do |arg|
        if void_lib_call?(arg)
          arg.raise "passing Void return value of lib fun call has no effect"
        end
      end

      named_args.try &.each do |arg|
        if void_lib_call?(arg)
          arg.raise "passing Void return value of lib fun call has no effect"
        end
      end

      obj = node.obj
      obj_type = obj.try &.type?
      block = node.block

      # It might happen that a call was made on a module or an abstract class
      # and we don't know the type because there are no including classes or subclasses.
      # In that case, turn this into an untyped expression.
      if !node.type? && obj && obj_type && (obj_type.module? || obj_type.abstract? || obj_type.is_a?(GenericType))
        return untyped_expression(node, "`#{node}` has no type")
      end

      if block && (fun_literal = block.fun_literal)
        block.fun_literal = fun_literal.transform(self)
      end

      # Check if we have an untyped expression in this call. Replace it with raise.
      if (obj && !obj_type)
        return untyped_expression(node, "`#{obj}` has no type")
      end

      node.args.each do |arg|
        unless arg.type?
          return untyped_expression(node, "`#{arg}` has no type")
        end
      end

      node.named_args.try &.each do |named_arg|
        unless named_arg.value.type?
          return untyped_expression(node, "`#{named_arg}` has no type")
        end
      end

      # Check if the block has its type frozen and it doesn't match the current type
      if block && (freeze_type = block.freeze_type) && (block_type = block.type?)
        unless block_type.implements?(freeze_type)
          freeze_type = freeze_type.base_type if freeze_type.is_a?(VirtualType)
          node.raise "expected block to return #{freeze_type}, not #{block_type}"
        end
      end

      # If any expression is no-return, replace the call with its expressions up to
      # the one that no returns.
      if (obj.try &.type?.try &.no_return?) || (node.args.any? &.type?.try &.no_return?) ||
         (node.named_args.try &.any? &.value.type?.try &.no_return?)
        call_exps = [] of ASTNode
        call_exps << obj if obj
        unless obj.try &.type?.try &.no_return?
          node.args.each do |arg|
            call_exps << arg
            break if arg.type?.try &.no_return?
          end
          node.named_args.try &.each do |named_arg|
            call_exps << named_arg.value
            break if named_arg.value.type?.try &.no_return?
          end
        end
        exps = Expressions.new(call_exps)
        exps.set_type(call_exps.last.type?) unless call_exps.empty?
        return exps
      end

      if target_defs = node.target_defs
        if target_defs.size == 1
          if target_defs[0].is_a?(External)
            check_args_are_not_closure node, "can't send closure to C function"
          elsif obj_type && obj_type.extern? && node.name.ends_with?('=')
            check_args_are_not_closure node, "can't set closure as C #{obj_type.type_desc} member"
          end
        end

        current_def = @current_def

        target_defs.each do |target_def|
          if @transformed.add?(target_def)
            node.bubbling_exception do
              @current_def = target_def
              @def_nest_count += 1
              target_def.body = target_def.body.transform(self)
              @def_nest_count -= 1
              @current_def = current_def
            end
          end

          # If the current call targets a method that raises, the method
          # where the call happens also raises.
          current_def.raises = true if current_def && target_def.raises?
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

      node.replace_splats

      # Convert named arguments to regular arguments, because intermediate
      # defs with the needed number of arguments are already defined.
      if named_args = node.named_args
        named_args.each do |named_arg|
          node.args << named_arg.value
        end
        node.named_args = nil
      end

      node
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
        if @a_def.vars.try &.[node.name]?.try &.closured?
          @vars << node
        end
        false
      end

      def visit(node : InstanceVar)
        @vars << node
        false
      end

      def visit(node : ASTNode)
        true
      end
    end

    def check_args_are_not_closure(node, message)
      node.args.each do |arg|
        check_arg_is_not_closure(node, message, arg)
      end
    end

    def check_arg_is_not_closure(node, message, arg)
      case arg
      when Expressions
        arg.expressions.each do |exp|
          check_arg_is_not_closure(node, message, exp)
        end
      when Call
        # If the call simply returns its captured block unchanged, we can detect
        # closured vars inside the block during compile-time
        if target_def_is_captured_block?(arg)
          check_arg_is_not_closure(node, message, arg.block.not_nil!.fun_literal)
        end
      when ProcLiteral
        if proc_pointer = arg.proc_pointer
          case proc_pointer.obj
          when Var
            arg.raise "#{message} (closured vars: #{proc_pointer.obj})"
          when InstanceVar
            arg.raise "#{message} (closured vars: self)"
          end
        end

        if arg.def.closure?
          vars = ClosuredVarsCollector.collect arg.def
          if vars.empty?
            message += " (closured vars: self)"
          else
            message += " (closured vars: #{vars.join ", "})"
          end

          arg.raise message
        end
      when ProcPointer
        if expanded = arg.expanded
          return check_arg_is_not_closure(node, message, expanded)
        end

        if arg.obj.try &.type?.try &.passed_as_self?
          arg.raise "#{message} (closured vars: self)"
        end

        owner = arg.call.target_def.owner
        if owner.passed_as_self?
          arg.raise "#{message} (closured vars: self)"
        end
      end
    end

    # Checks whether *arg*'s target def has the following definition:
    #
    # ```
    # def f(&block)
    #   block
    # end
    # ```
    #
    # That is, the def returns its captured block and does nothing else. An
    # example is Proc.new(&block).
    def target_def_is_captured_block?(arg : Call)
      a_def = arg.target_defs.try &.first
      return false unless a_def

      block_arg = a_def.block_arg
      return false unless block_arg

      body_var = a_def.body.as?(Var)
      return false unless body_var && body_var.name == block_arg.name

      true
    end

    def transform(node : ProcPointer)
      super

      if expanded = node.expanded
        return transform(expanded)
      end

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

    def transform(node : ProcLiteral)
      body = node.def.body
      if node.def.no_returns? && !body.type?
        node.def.body = untyped_expression(body)
      else
        node.def.body = node.def.body.transform(self)
      end
      node
    end

    def untyped_expression(node, msg = nil)
      ex_msg = String.build do |str|
        str << "can't execute `" << node << "` at " << node.location
        if msg
          str << ": "
          str << msg
        end
      end

      build_raise ex_msg, node
    end

    def build_raise(msg : String, node : ASTNode)
      call = Call.global("raise", StringLiteral.new(msg).at(node)).at(node)
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
      no_return_index = node.exps.index { |exp| !exp.type? || exp.no_returns? }
      if no_return_index
        exps = Expressions.new(node.exps[0, no_return_index + 1])
        exps.bind_to(exps.expressions.last)
        return exps
      end

      node
    end

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
      cond_is_truthy, cond_is_falsey = compute_last_truthiness do
        node.cond = node.cond.transform(self)
      end

      node_cond = node.cond

      if node_cond.no_returns?
        return node_cond
      end

      case
      when node_cond.true_literal?
        node.truthy = true
      when node_cond.false_literal?
        node.falsey = true
      when (cond_type = node_cond.type?) && cond_type.nil_type?
        node.falsey = true
      when cond_is_truthy
        node.truthy = true
      when cond_is_falsey
        node.falsey = true
      else
        # Not a special condition
      end

      if node.falsey?
        then_is_truthy = false
        then_is_falsey = false
      else
        then_is_truthy, then_is_falsey = compute_last_truthiness do
          node.then = node.then.transform(self)
        end
      end

      if node.truthy?
        else_is_truthy = false
        else_is_falsey = false
      else
        else_is_truthy, else_is_falsey = compute_last_truthiness do
          node.else = node.else.transform(self)
        end
      end

      case node
      when .and?
        @last_is_truthy = cond_is_truthy && then_is_truthy
        @last_is_falsey = cond_is_falsey || then_is_falsey
      when .or?
        @last_is_truthy = cond_is_truthy || else_is_truthy
        @last_is_falsey = cond_is_falsey && else_is_falsey
      else
        reset_last_status
      end

      node
    end

    def transform(node : IsA)
      super
      reset_last_status
      if replacement = node.syntax_replacement
        return replacement.transform(self)
      end

      const_type = node.const.type?
      return untyped_expression(node) unless const_type

      transform_is_a_or_responds_to node, &.filter_by(const_type)
    end

    def transform(node : RespondsTo)
      super
      reset_last_status
      transform_is_a_or_responds_to node, &.filter_by_responds_to(node.name)
    end

    def transform_is_a_or_responds_to(node, &)
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

      if node.obj.no_returns?
        return node.obj
      end

      to_type = node.to.type

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
      else
        resulting_type = obj_type.filter_by(to_type)
        unless resulting_type
          node.raise "can't cast #{obj_type} to #{to_type}"
        end
      end

      node
    end

    def transform(node : NilableCast)
      node = super

      if node.obj.no_returns?
        return node.obj
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

      node
    end

    def transform(node : InstanceSizeOf)
      exp_type = node.exp.type?

      if exp_type
        instance_type = exp_type.devirtualize
        if instance_type.struct? || instance_type.module? || instance_type.metaclass? || instance_type.is_a?(UnionType)
          node.exp.raise "instance_sizeof can only be used with a class, but #{instance_type} is a #{instance_type.type_desc}"
        end
      end

      if expanded = node.expanded
        return expanded.transform self
      end

      node
    end

    def transform(node : InstanceAlignOf)
      exp_type = node.exp.type?

      if exp_type
        instance_type = exp_type.devirtualize
        if instance_type.struct? || instance_type.module? || instance_type.metaclass? || instance_type.is_a?(UnionType)
          node.exp.raise "instance_alignof can only be used with a class, but #{instance_type} is a #{instance_type.type_desc}"
        end
      end

      if expanded = node.expanded
        return expanded.transform self
      end

      node
    end

    def transform(node : TupleLiteral)
      super

      unless node.elements.all? &.type?
        return untyped_expression node
      end

      no_return_index = node.elements.index &.no_returns?
      if no_return_index
        exps = Expressions.new(node.elements[0, no_return_index + 1])
        exps.bind_to(exps.expressions.last)
        return exps
      end

      # `node.program` is assigned by `MainVisitor` usually, however
      # it may not be assigned in some edge-case (e.g. this `node` is placed
      # at not invoked block.). This assignment is for it.
      node.program = @program
      node.update

      node
    end

    def transform(node : NamedTupleLiteral)
      super

      unless node.entries.all? &.value.type?
        return untyped_expression node
      end

      no_return_index = node.entries.index &.value.no_returns?
      if no_return_index
        exps = Expressions.new(node.entries[0, no_return_index + 1].map &.value)
        exps.bind_to(exps.expressions.last)
        return exps
      end

      node.program = @program
      node.update

      node
    end

    def transform(node : CStructOrUnionDef)
      type = node.resolved_type.as(NonGenericClassType)
      node.raise "empty #{type.type_desc}s are disallowed" if type.instance_vars.empty?
      node
    end

    def transform(node : Primitive)
      extra = node.extra
      extra = extra.transform(self) if extra

      # For `allocate` on a virtual abstract type we make `extra`
      # be a call to `raise` at runtime. Here we just replace the
      # "allocate" primitive with that raise call.
      if node.name.in?("allocate", "pre_initialize") && extra
        return extra
      end

      node.extra = extra
      node
    end

    def transform(node : TypeOf)
      node = super

      unless node.type?
        node.unbind_from node.dependencies
        node.bind_to node.expressions
      end

      node
    end

    def transform(node : AssignWithRestriction)
      transform(node.assign)
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
          when "+", "-", "*", "&+", "&-", "&*", "/", "//", "&", "|"
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

require "./repl"
require "./instructions"

# The compiler is in charge of turning Crystal AST into bytecode,
# which is just a stream of bytes that tells the interpreter what to do.
class Crystal::Repl::Compiler < Crystal::Visitor
  # A block that's being compiled: what's the block,
  # and which def will invoke it.
  record CompilingBlock, block : Block, target_def : Def

  # A local variable: the index in the stack where it's located, and its type
  record LocalVar, index : Int32, type : Type

  # A closured variable: the array of indexes to traverse the closure context,
  # and possibly parent context, to reach the variable with the given type.
  record ClosuredVar, indexes : Array(Int32), type : Type

  # Information about closured variables in a given context.
  class ClosureContext
    # The variables closures in the closest context
    getter vars : Hash(String, {Int32, Type})

    # The self type, if captured, otherwise nil.
    # Comes after vars, at the end of the closure (this closure never has a parent closure).
    getter self_type : Type?

    # The parent context, if any, where more closured variables might be reached
    getter parent : ClosureContext?

    # The total bytesize to hold all the immediate closure data.
    # If this context has a parent context, it will come at the end of this
    # data and occupy 8 bytes.
    getter bytesize : Int32

    def initialize(
      @vars : Hash(String, {Int32, Type}),
      @self_type : Type?,
      @parent : ClosureContext?,
      @bytesize : Int32
    )
    end
  end

  # What's `self` when compiling a node.
  private getter scope : Type

  # The method that's being compiled, if any
  # (if `nil`, the node happens at the top-level)
  private getter def : Def?

  # The block we are in, if any.
  # This is different than `compiling_block`. Consider this code:
  #
  # ```
  # def foo
  #   # When this is called from the top-level, `compiled_block`
  #   # will be the block given to `foo`, but `compiling_block`
  #   # will be `nil` because we are not compiling a block.
  #
  #   bar do
  #     # Now we are compiling `bar`, so `compiling_block` will
  #     # have this block and `bar` as a value.
  #     # And also, `compiled_block` is still the block given to `foo`.
  #     # This is the point where you can see their difference.
  #     yield
  #   end
  # end
  #
  # def bar
  #   yield
  # end
  #
  # # Here `compiling_block` and `compiled_block` are `nil`.
  #
  # foo do
  #   # When this block is compiled, `compiling_block` will have
  #   # the block and `foo`.
  #   a = 1
  # end
  # ```
  property compiled_block : CompiledBlock?

  @compiling_block : CompilingBlock?

  # The instructions that are being generated.
  getter instructions : CompiledInstructions

  # In which block level we are in.
  # Right when we enter a def we are at block level 0.
  # When entering a block, the block level is incremented.
  #
  # This is useful to distinguish a same variable in multiple
  # scopes, for example:
  #
  # ```
  # a = 0      # has block_level = 0
  # foo do |a| # <- this is a different variable, has block_level = 1
  # end
  # ```
  property block_level = 0

  @closure_context : ClosureContext?

  def initialize(
    @context : Context,
    @local_vars : LocalVars,
    @instructions : CompiledInstructions = CompiledInstructions.new,
    scope : Type? = nil,
    @def = nil,
    @top_level = true
  )
    @scope = scope || @context.program

    # Do we want to push a value to the stack?
    # This value is false for nodes whose value is not needed.
    # For example, consider this code:
    #
    # ```
    # a = 1
    # 2
    # a
    # ```
    #
    # The value of the second node, `2`, is not needed at all
    # and so it's not even pushed to the stack.
    #
    # And, actually, the value of `a = 1` is not needed either
    # (it's not assigned to anything else after `a`).
    #
    # An alternative way to have done this is to push every
    # node to the stack, and pop afterwards if not needed
    # (this is in intermediary nodes of `Expressions`) but
    # this is less efficient.
    @wants_value = true

    # Do we want to produce a struct pointer instead of a struct
    # value?
    #
    # This is needed because a struct call receiver is actually
    # passed as a pointer, which becomes `self`. Then through
    # this pointer struct mutation is possible.
    #
    # For code like:
    #
    # ```
    # @foo.bar
    # ```
    #
    # this is handled by checking whether the receiver is an InstanceVar,
    # and if so, we load a pointer to the instance var.
    #
    # But what if it's something like this:
    #
    # ```
    # (cond ? @foo : @bar).bar
    # ```
    #
    # Assuming `@foo` and `@bar` have the same type, and `bar` mutates
    # them, we'd like to pass a pointer to them here too.
    # In this case we set `@wants_struct_pointer` to true, and then
    # when an instance variable is visited, we put the pointer instead
    # of the value. In this particular case we actually put some zeros
    # (the size of the struct) before the pointer because we don't know
    # whether other branches of the `if` (or expressions, in general)
    # will actually put a full struct followed by a pointer. For example:
    #
    # ```
    # (cond ? @foo : some_call).bar
    # ```
    #
    # In this case `some_call` returns a struct, and we'll push it to the
    # stack, and then we'll push a pointer to it. After `bar` is done
    # we remove the extra struct before the pointer. So in the case of
    # `@foo`, it must also produce something that's like `struct - pointer`
    # so that the struct is popped uniformly.
    @wants_struct_pointer = false
  end

  def self.new(
    context : Context,
    compiled_def : CompiledDef,
    top_level : Bool
  )
    new(
      context: context,
      local_vars: compiled_def.local_vars,
      instructions: compiled_def.instructions,
      scope: compiled_def.owner,
      def: compiled_def.def,
      top_level: top_level,
    )
  end

  # Compile bytecode instructions for the given node.
  def compile(node : ASTNode) : Nil
    # If at the top-level, check if there's closure data
    prepare_closure_context(@context.program) unless @def

    node.accept self

    # Use a dummy node so that pry stops at `end`
    leave aligned_sizeof_type(node), node: Nop.new.at(node.end_location)
  end

  # Compile bytecode instructions for the given block, where `target_def`
  # is the method that will yield to the block.
  def compile_block(node : Block, target_def : Def, parent_closure_context : ClosureContext?) : Nil
    prepare_closure_context(node, parent_closure_context: parent_closure_context)

    @compiling_block = CompilingBlock.new(node, target_def)

    # Right when we enter a block we have the block arguments in the stack:
    # we need to copy the values to the respective block arguments, which
    # are really local variables inside the enclosing method.
    # And we have to do them starting from the end because it's a stack.
    node.args.reverse_each do |arg|
      block_var = node.vars.not_nil![arg.name]

      # If any block argument is closured, we need to store it in the closure
      if block_var.type? && block_var.closure_in?(node)
        closured_var = lookup_closured_var(arg.name)
        assign_to_closured_var(closured_var, node: nil)
      else
        index = @local_vars.name_to_index(block_var.name, @block_level)
        # Don't use location so we don't pry break on a block arg (useless)
        set_local index, aligned_sizeof_type(block_var), node: nil
      end
    end

    node.body.accept self
    upcast node.body, node.body.type, node.type

    # Use a dummy node so that pry stops at `end`
    leave aligned_sizeof_type(node), node: Nop.new.at(node.end_location)
  end

  # Compile bytecode instructions for the given method.
  def compile_def(node : Def, parent_closure_context : ClosureContext? = nil, closure_owner = node) : Nil
    prepare_closure_context(
      node,
      closure_owner: closure_owner,
      parent_closure_context: parent_closure_context,
    )

    # If any def argument is closured, we need to store it in the closure
    node.args.each do |arg|
      var = node.vars.not_nil![arg.name]
      if var.type? && var.closure_in?(node)
        local_var = lookup_local_var(var.name)
        closured_var = lookup_closured_var(var.name)

        get_local local_var.index, aligned_sizeof_type(local_var.type), node: nil
        assign_to_closured_var(closured_var, node: nil)
      end
    end

    node.body.accept self

    final_type = node.type

    compiled_block = @compiled_block
    if compiled_block
      final_type = merge_block_break_type(final_type, compiled_block.block)
    end

    if final_type.nil_type?
      # Cast whatever was returned to Nil, which means just popping it from the stack
      if node.body.type?
        pop aligned_sizeof_type(node.body), node: nil
      else
        # Nothing to do, there's no body type which probably means
        # the last expression in the body is unreachable, and given
        # that this already returns nil, the value was already "casted" to nil
      end
    elsif final_type.no_return?
      # Nothing to do, the body never returns so there's nothing to upcast
    else
      upcast node.body, node.body.type, final_type
    end

    # Use a dummy node so that pry stops at `end`
    leave aligned_sizeof_type(final_type), node: Nop.new.at(node.end_location)

    @instructions
  end

  private def inside_method?
    return false if @top_level

    !!@def
  end

  def visit(node : Nop)
    return false unless @wants_value

    put_nil node: node
    false
  end

  def visit(node : NilLiteral)
    return false unless @wants_value

    put_nil node: node
    false
  end

  def visit(node : BoolLiteral)
    return false unless @wants_value

    if node.value
      put_true node: node
    else
      put_false node: node
    end

    false
  end

  def visit(node : NumberLiteral)
    return false unless @wants_value

    compile_number(node, node.kind, node.value)

    false
  end

  private def compile_number(node, kind, value)
    case kind
    when :i8
      put_i8 value.to_i8, node: node
    when :u8
      put_u8 value.to_u8, node: node
    when :i16
      put_i16 value.to_i16, node: node
    when :u16
      put_u16 value.to_u16, node: node
    when :i32
      put_i32 value.to_i32, node: node
    when :u32
      put_u32 value.to_u32, node: node
    when :i64
      put_i64 value.to_i64, node: node
    when :u64
      put_u64 value.to_u64, node: node
    when :f32
      put_i32 value.to_f32.unsafe_as(Int32), node: node
    when :f64
      put_i64 value.to_f64.unsafe_as(Int64), node: node
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{kind}"
    end
  end

  def visit(node : CharLiteral)
    return false unless @wants_value

    put_i32 node.value.ord, node: node
    false
  end

  def visit(node : StringLiteral)
    return false unless @wants_value

    # TODO: use a string pool?
    put_i64 node.value.object_id.unsafe_as(Int64), node: node
    false
  end

  def visit(node : SymbolLiteral)
    return false unless @wants_value

    index = @context.symbol_index(node.value)

    put_i32 index, node: node
    false
  end

  def visit(node : TupleLiteral)
    type = node.type.as(TupleInstanceType)

    # A tuple potentially has the values packed (unaligned).
    # The values in the stack are aligned, so we must adjust that:
    # if the value in the stack has more bytes than needed, we pop
    # the extra ones; if it has less bytes that needed we pad the value
    # with zeros.
    current_offset = 0
    node.elements.each_with_index do |element, i|
      element.accept self
      aligned_size = aligned_sizeof_type(element)
      next_offset =
        if i == node.elements.size - 1
          aligned_sizeof_type(type)
        else
          @context.offset_of(type, i + 1)
        end

      difference = next_offset - (current_offset + aligned_size)
      if difference > 0
        push_zeros(difference, node: nil)
      elsif difference < 0
        pop(-difference, node: nil)
      end

      current_offset = next_offset
    end

    false
  end

  def visit(node : NamedTupleLiteral)
    type = node.type.as(NamedTupleInstanceType)

    # This logic is similar to TupleLiteral.
    current_offset = 0
    node.entries.each_with_index do |entry, i|
      entry.value.accept self
      aligned_size = aligned_sizeof_type(entry.value)
      next_offset =
        if i == node.entries.size - 1
          aligned_sizeof_type(type)
        else
          @context.offset_of(type, i + 1)
        end

      difference = next_offset - (current_offset + aligned_size)
      if difference > 0
        push_zeros(difference, node: nil)
      elsif difference < 0
        pop(-difference, node: nil)
      end

      current_offset = next_offset
    end

    false
  end

  def visit(node : ExceptionHandler)
    # TODO: rescues, else, etc.
    rescues = node.rescues
    node_ensure = node.ensure

    # Accept the body, recording where it starts and ends
    body_start_index = instructions_index
    node.body.accept self
    upcast node.body, node.body.type, node.type
    body_end_index = instructions_index

    # Now we'll write the catch tables so we want to skip this
    jump 0, node: nil
    jump_location = patch_location

    # Assume we have only rescue for now
    rescue_locations = [] of Int32

    rescues.try &.each do |a_rescue|
      name = a_rescue.name
      types = a_rescue.types
      if types
        exception_types = types.map(&.type.instance_type)
      else
        exception_types = [@context.program.exception] of Type
      end

      instructions.add_rescue(
        body_start_index,
        body_end_index,
        exception_types,
        jump_index: instructions_index)

      if name
        # The exception is in the stack, so we copy it to the corresponding local variable
        name_type = @context.program.type_merge_union_of(exception_types).not_nil!

        assign_to_var(name, name_type, node: a_rescue)
      else
        # The exception is in the stack but we don't use it
        pop sizeof(Void*), node: nil
      end

      a_rescue.body.accept self
      upcast a_rescue.body, a_rescue.body.type, node.type

      jump 0, node: nil
      rescue_locations << patch_location
    end

    if node_ensure
      # If there's an ensure block we also generate another ensure
      # clause to be executed when an exception is raised inside the body
      # or any of the rescue clauses, which does the ensure, then reraises
      rescues_end_index = instructions_index

      instructions.add_ensure(
        body_start_index,
        rescues_end_index,
        jump_index: instructions_index)

      discard_value node_ensure

      # TODO: instead of having a reraise instruction and storing the exception
      # in a global variable (like in Ruby), we could have a dedicated local
      # variable slot for it.
      reraise node: nil
    end

    # Now we are at the exit
    patch_jump(jump_location)

    rescue_locations.each do |location|
      patch_jump(location)
    end

    discard_value node_ensure if node_ensure

    false
  end

  def visit(node : Expressions)
    old_wants_value = @wants_value
    old_wants_struct_pointer = @wants_struct_pointer

    node.expressions.each_with_index do |expression, i|
      @wants_value = old_wants_value && i == node.expressions.size - 1
      @wants_struct_pointer = old_wants_struct_pointer && i == node.expressions.size - 1
      expression.accept self
    end

    @wants_value = old_wants_value
    @wants_struct_pointer = old_wants_struct_pointer

    false
  end

  def visit(node : Assign)
    target = node.target
    case target
    when Var
      dont_request_struct_pointer do
        request_value(node.value)
      end

      # If it's the case of `x = a = 1` then we need to preserve the value
      # of 1 in the stack because it will be assigned to `x` too
      # (set_local removes the value from the stack)
      if @wants_value && !@wants_struct_pointer
        dup(aligned_sizeof_type(node.value), node: nil)
      end

      assign_to_var(target.name, node.value.type, node: node)
    when InstanceVar
      if inside_method?
        dont_request_struct_pointer do
          request_value(node.value)
        end

        # Why we dup: check the Var case (it's similar)
        if @wants_value && !@wants_struct_pointer
          dup(aligned_sizeof_type(node.value), node: nil)
        end

        ivar_offset = ivar_offset(scope, target.name)
        ivar = scope.lookup_instance_var(target.name)
        ivar_size = inner_sizeof_type(ivar.type)

        upcast node.value, node.value.type, ivar.type

        set_self_ivar ivar_offset, ivar_size, node: node

        # If this assignment is part of a call that needs a struct pointer, produce it now
        if @wants_struct_pointer
          push_zeros aligned_sizeof_type(node), node: nil
          compile_pointerof_ivar(node, target.name)

          # In case the instance variable is a union, offset the pointer
          # to where the union value is
          if ivar.type.is_a?(MixedUnionType)
            put_i32 sizeof(Void*), node: nil
            pointer_add 1, node: nil
          end
        end
      else
        node.type = @context.program.nil_type
        put_nil node: nil if @wants_value
      end
    when ClassVar
      if inside_method?
        index, compiled_def = class_var_index_and_compiled_def(target)

        if compiled_def
          initialize_class_var_if_needed(target.var, index, compiled_def)
        end

        dont_request_struct_pointer do
          request_value(node.value)
        end

        # Why we dup: check the Var case (it's similar)
        if @wants_value && !@wants_struct_pointer
          dup(aligned_sizeof_type(node.value), node: nil)
        end

        var = target.var

        upcast node.value, node.value.type, var.type

        set_class_var index, aligned_sizeof_type(var), node: node

        # If this assignment is part of a call that needs a struct pointer, produce it now
        if @wants_struct_pointer
          push_zeros aligned_sizeof_type(node), node: nil
          pointerof_class_var(index, node: node)

          # In case the class variable is a union, offset the pointer
          # to where the union value is
          if var.type.is_a?(MixedUnionType)
            put_i32 sizeof(Void*), node: nil
            pointer_add 1, node: nil
          end
        end
      else
        # TODO: eagerly initialize the class var?
        node.type = @context.program.nil_type
        put_nil node: nil if @wants_value
      end
    when Underscore
      node.value.accept self
    when Path
      const = target.target_const.not_nil!

      # We inline simple constants.
      if const.value.simple_literal?
        const.value.accept self

        # Not all non-trivial constants have a corresponding def:
        # for example ARGV_UNSAFE.
      elsif const.fake_def
        index, compiled_def = get_const_index_and_compiled_def const

        # This will initialize the constant
        const_initialized index, node: nil
        pop(sizeof(Pointer(Void)), node: nil) # pop the bool value

        call compiled_def, node: nil

        # Why we dup: check the Var case (it's similar)
        dup(aligned_sizeof_type(const.value.type), node: nil) if @wants_value
        set_const index, aligned_sizeof_type(const.value), node: nil
      elsif @wants_value
        node.raise "BUG: missing interprter assign constant that isn't 'used'"
      end
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  private def assign_to_var(name : String, value_type : Type, *, node : ASTNode?)
    var = lookup_closured_var_or_local_var(name)
    case var
    in LocalVar
      index, type = var.index, var.type

      # Before assigning to the var we must potentially box inside a union
      upcast node, value_type, type
      set_local index, aligned_sizeof_type(type), node: node

      # If this assignment is part of a call that needs a struct pointer, produce it now
      if @wants_struct_pointer
        push_zeros aligned_sizeof_type(node), node: nil
        pointerof_var index, node: node
      end
    in ClosuredVar
      raise_if_wants_struct_pointer(node)

      # Before assigning to the var we must potentially box inside a union
      upcast node, value_type, var.type

      assign_to_closured_var(var, node: node)
    end
  end

  def visit(node : Var)
    return false unless @wants_value

    local_var = lookup_closured_var_or_local_var(node.name)
    case local_var
    in LocalVar
      index, type = local_var.index, local_var.type

      if node.name == "self" && type.passed_by_value?
        if @wants_struct_pointer
          push_zeros aligned_sizeof_type(scope), node: nil
          put_self(node: node)
          return false
        else
          # Load the entire self from the pointer that's self
          get_self_ivar 0, aligned_sizeof_type(type), node: node
        end
      else
        if @wants_struct_pointer
          push_zeros aligned_sizeof_type(node), node: nil
          pointerof_var index, node: node
        else
          get_local index, aligned_sizeof_type(type), node: node
        end
      end

      downcast node, type, node.type
    in ClosuredVar
      if node.name == "self" && local_var.type.passed_by_value?
        if @wants_struct_pointer
          node.raise "BUG: missing interpret read closured var with self wants_struct_pointer"
        else
          node.raise "BUG: missing interpret read closured var with self"
        end
      else
        if @wants_struct_pointer
          node.raise "BUG: missing interpret read closured var with wants_struct_pointer"
        else
          read_from_closured_var(local_var, node: node)
        end
      end
    end

    false
  end

  def lookup_closured_var_or_local_var(name : String) : LocalVar | ClosuredVar
    lookup_closured_var?(name) ||
      lookup_local_var?(name) ||
      raise("BUG: can't find closured var or local var #{name}")
  end

  def lookup_local_var(name : String) : LocalVar
    lookup_local_var?(name) || raise("BUG: can't find local var #{name}")
  end

  def lookup_local_var?(name : String) : LocalVar?
    block_level = @block_level
    while block_level >= 0
      index = @local_vars.name_to_index?(name, block_level)
      if index
        type = @local_vars.type(name, block_level)
        return LocalVar.new(index, type)
      end

      block_level -= 1
    end

    nil
  end

  def lookup_closured_var(name : String) : ClosuredVar
    lookup_closured_var?(name) || raise("BUG: can't find closured var #{name}")
  end

  def lookup_closured_var?(name : String) : ClosuredVar?
    closure_context = @closure_context
    return unless closure_context

    indexes = [] of Int32

    type = lookup_closured_var?(name, closure_context, indexes)

    return nil if indexes.empty? || !type

    ClosuredVar.new(indexes, type)
  end

  def lookup_closured_var?(name : String, closure_context : ClosureContext, indexes : Array(Int32))
    if name == "self" && (closure_self_type = closure_context.self_type)
      indexes << closure_context.bytesize - aligned_sizeof_type(closure_self_type)
      return closure_self_type
    end

    closured_var = closure_context.vars[name]?
    if closured_var
      indexes << closured_var[0]
      return closured_var[1]
    end

    parent_context = closure_context.parent
    return nil unless parent_context

    indexes << closure_context.bytesize - sizeof(Void*)
    lookup_closured_var?(name, parent_context, indexes)
  end

  private def prepare_closure_context(vars_owner, closure_owner = vars_owner, parent_closure_context = nil)
    closure_self_type = nil
    if closure_owner.is_a?(Def) && closure_owner.self_closured?
      closure_self_type = closure_owner.owner
    end

    if parent_closure_context
      @closure_context = parent_closure_context
    end

    closured_vars, closured_vars_bytesize = compute_closured_vars(vars_owner.vars, closure_owner)

    # If there's no closure in this context, we might still have a closure
    # if the parent formed a closure
    if closured_vars.empty? && !closure_self_type
      @closure_context = parent_closure_context
      return
    end

    if parent_closure_context
      closured_vars_bytesize += sizeof(Void*)
    end

    if closure_self_type
      closured_vars_bytesize += aligned_sizeof_type(closure_self_type)
    end

    closure_context = ClosureContext.new(
      vars: closured_vars,
      parent: parent_closure_context,
      self_type: closure_self_type,
      bytesize: closured_vars_bytesize,
    )
    @closure_context = closure_context

    # Allocate closure heap memory
    put_i32 closure_context.bytesize, node: nil
    pointer_malloc 1, node: nil

    # Store the pointer in the closure context local variable
    index = @local_vars.name_to_index(Closure::VAR_NAME, @block_level)
    set_local index, sizeof(Void*), node: nil

    # If there's a closured self type, store it now
    if closure_self_type
      # Load self
      # (pointer_set expects the value to come before the pointer)
      local_self_index = @local_vars.name_to_index("self", 0)
      get_local local_self_index, aligned_sizeof_type(closure_self_type), node: nil

      # Get the closure pointer
      get_local index, sizeof(Void*), node: nil

      # Offset pointer to reach self pointer
      closure_self_index = closure_context.bytesize - aligned_sizeof_type(closure_self_type)
      if closure_self_index > 0
        put_i32 closure_self_index, node: nil
        pointer_add 1, node: nil
      end

      # Store self in closure
      pointer_set aligned_sizeof_type(closure_self_type), node: nil
    end

    if parent_closure_context
      # Find the closest parent closure
      block_level = @block_level
      while true
        # Only at block level 0 we have a proc closure data
        if block_level == 0
          parent_index = @local_vars.name_to_index?(Closure::ARG_NAME, block_level)
          break if parent_index
        end

        block_level -= 1
        break if block_level < 0

        parent_index = @local_vars.name_to_index?(Closure::VAR_NAME, block_level)
        break if parent_index
      end

      unless parent_index
        raise "Can't find parent closure index"
      end

      get_local parent_index, sizeof(Void*), node: nil
      read_closured_var_pointer ClosuredVar.new(
        indexes: [closured_vars_bytesize - sizeof(Void*)] of Int32,
        type: @context.program.pointer_of(@context.program.void),
      ), node: nil
      pointer_set(sizeof(Void*), node: nil)
    end
  end

  private def compute_closured_vars(vars, closure_owner)
    closured_vars = {} of String => {Int32, Type}
    closure_var_index = 0

    vars.try &.each do |name, var|
      if var.type? && var.closure_in?(closure_owner)
        closured_vars[name] = {closure_var_index, var.type}
        closure_var_index += aligned_sizeof_type(var)
      end
    end

    {closured_vars, closure_var_index}
  end

  private def assign_to_closured_var(closured_var : ClosuredVar, *, node : ASTNode?)
    read_closured_var_pointer(closured_var, node: nil)

    # Now we have the value in the stack, and the pointer.
    # This is the correct order for pointer_set
    pointer_set(aligned_sizeof_type(closured_var.type), node: node)
  end

  private def read_from_closured_var(closured_var : ClosuredVar, *, node : ASTNode?)
    read_closured_var_pointer(closured_var, node: nil)

    # Now read from the pointer
    pointer_get inner_sizeof_type(closured_var.type), node: node
  end

  private def read_closured_var_pointer(closured_var : ClosuredVar, *, node : ASTNode?)
    indexes, type = closured_var.indexes, closured_var.type

    # First load the closure pointer
    closure_var_index = get_closure_var_index
    get_local closure_var_index, sizeof(Void*), node: nil

    # Now find the var through the pointer
    indexes.each_with_index do |index, i|
      if i == indexes.size - 1
        # We reached the context where the var is.
        # No need to offset if index is 0
        if index > 0
          put_i32 index, node: nil
          pointer_add 1, node: nil
        end
      else
        # The var is in the parent context, so load that first
        put_i32 index, node: nil
        pointer_add 1, node: nil
        pointer_get sizeof(Void*), node: nil
      end
    end
  end

  private def get_closure_var_index
    # It might be that there's no closure in the current block,
    # so we must search in parent blocks or the enclosing method
    block_level = @block_level
    while block_level >= 0
      closure_var_index = @local_vars.name_to_index?(Closure::VAR_NAME, block_level)
      return closure_var_index if closure_var_index

      block_level -= 1
    end

    raise "BUG: can't find closure var index starting from block level #{@block_level}"
  end

  def visit(node : InstanceVar)
    compile_instance_var(node)
  end

  private def compile_instance_var(node : InstanceVar)
    return false unless @wants_value

    if @wants_struct_pointer
      push_zeros aligned_sizeof_type(node), node: nil
      compile_pointerof_ivar(node, node.name)
    else
      ivar_offset = ivar_offset(scope, node.name)
      ivar_size = inner_sizeof_type(scope.lookup_instance_var(node.name))

      get_self_ivar ivar_offset, ivar_size, node: node
    end

    false
  end

  def visit(node : ClassVar)
    return false unless @wants_value

    index, compiled_def = class_var_index_and_compiled_def(node)

    if compiled_def
      initialize_class_var_if_needed(node.var, index, compiled_def)
    end

    if @wants_struct_pointer
      push_zeros aligned_sizeof_type(node), node: nil
      pointerof_class_var(index, node: node)
    else
      get_class_var index, aligned_sizeof_type(node.var), node: node
    end

    false
  end

  private def class_var_index_and_compiled_def(node : ClassVar) : {Int32, CompiledDef?}
    var = node.var

    case var.owner
    when VirtualType
      node.raise "BUG: missing interpret class var for virtual type"
    when VirtualMetaclassType
      node.raise "BUG: missing interpret class var for virtual metaclass type"
    end

    index_and_compiled_def = @context.class_var_index_and_compiled_def(var.owner, var.name)
    return index_and_compiled_def if index_and_compiled_def

    initializer = var.initializer
    if initializer
      value = initializer.node

      # It seems class variables initializers aren't cleaned up...
      value = @context.program.cleanup(value)

      def_name = "#{var.owner}::#{var.name}}"

      fake_def = Def.new(def_name)
      fake_def.owner = var.owner
      fake_def.vars = initializer.meta_vars
      fake_def.body = value
      fake_def.bind_to(value)

      compiled_def = CompiledDef.new(@context, fake_def, fake_def.owner, 0)

      # TODO: it's wrong that class variable initializer variables go to the
      # program, but this needs to be fixed in the main compiler first
      declare_local_vars(fake_def, compiled_def.local_vars, @context.program)

      # Declare local variables for the constant initializer
      # initializer.meta_vars.each do |name, var|
      #   var_type = var.type?
      #   next unless var_type

      #   compiled_def.local_vars.declare(name, var_type)
      # end

      compiler = Compiler.new(@context, compiled_def, top_level: true)
      compiler.compile_def(fake_def, closure_owner: @context.program)

      {% if Debug::DECOMPILE %}
        puts "=== #{def_name} ==="
        puts Disassembler.disassemble(@context, compiled_def)
        puts "=== #{def_name} ==="
      {% end %}
    end

    index = @context.declare_class_var(var.owner, var.name, var.type, compiled_def)

    {index, compiled_def}
  end

  def visit(node : ReadInstanceVar)
    compile_read_instance_var(node, node.obj, node.name)
  end

  private def compile_read_instance_var(node, obj, name)
    unless @wants_value
      discard_value(obj)
      return false
    end

    type = obj.type

    ivar_offset = ivar_offset(type, name)
    ivar_size = inner_sizeof_type(type.lookup_instance_var(name))

    unless @wants_struct_pointer
      obj.accept self

      if type.passed_by_value?
        # We have the struct in the stack, now we need to keep a part of it
        get_struct_ivar ivar_offset, ivar_size, aligned_sizeof_type(obj), node: node
      else
        get_class_ivar ivar_offset, ivar_size, node: node
      end

      return false
    end

    # @wants_struct_pointer is true

    # Remember to pad the pointer because it will be popped later on
    push_zeros(aligned_sizeof_type(node), node: nil)

    unless type.passed_by_value?
      dont_request_struct_pointer do
        obj.accept self
      end

      # At this point, for class types, we have a pointer on the stack,
      # so we just need to offset it
      put_i32 ivar_offset, node: nil
      pointer_add 1, node: nil

      return false
    end

    # At this point the obj tye is a pass-by-value type so we can't just
    # put it on the stack to get a pointer to it.
    # We need to get a pointer to it and then offset it.
    pop_obj = compile_struct_call_receiver(obj, obj.type)

    # Now offset it
    put_i32 ivar_offset, node: nil
    pointer_add 1, node: nil

    # And finally we need to pop the padding that was introduced by `compile_struct_call_receiver`, if any
    if pop_obj
      pop_from_offset aligned_sizeof_type(pop_obj), aligned_sizeof_type(node), node: nil
    end

    false
  end

  def visit(node : UninitializedVar)
    raise_if_wants_struct_pointer(node)

    case var = node.var
    when Var
      var.accept self
    when InstanceVar
      # Nothing to do
    when ClassVar
      # TODO: declare the class var (though it will be declared later on)
    else
      node.raise "BUG: missing interpret UninitializedVar for #{var.class}"
    end

    false
  end

  def visit(node : If)
    if node.truthy?
      discard_value(node.cond)
      node.then.accept self
      return false unless @wants_value

      upcast node.then, node.then.type, node.type
      return false
    elsif node.falsey?
      discard_value(node.cond)
      node.else.accept self
      return false unless @wants_value

      upcast node.else, node.else.type, node.type
      return false
    end

    dont_request_struct_pointer do
      request_value(node.cond)
    end

    value_to_bool(node.cond, node.cond.type)

    branch_unless 0, node: nil
    cond_jump_location = patch_location

    node.then.accept self
    upcast node.then, node.then.type, node.type if @wants_value

    jump 0, node: nil
    then_jump_location = patch_location

    patch_jump(cond_jump_location)

    node.else.accept self
    upcast node.else, node.else.type, node.type if @wants_value

    patch_jump(then_jump_location)

    false
  end

  def visit(node : While)
    raise_if_wants_struct_pointer(node)

    # Jump directly to the condition
    jump 0, node: nil
    cond_jump_location = patch_location

    body_index = instructions_index

    old_while = @while
    old_while_breaks = @while_breaks
    old_while_nexts = @while_nexts

    @while = node
    while_breaks = @while_breaks = [] of Int32
    while_nexts = @while_nexts = [] of Int32

    # Now write the body
    discard_value(node.body)

    # Here starts the condition.
    # Any `next` that happened leads us here.
    while_nexts.each do |while_next|
      patch_jump(while_next)
    end

    patch_jump(cond_jump_location)
    request_value(node.cond)
    value_to_bool(node.cond, node.cond.type)

    # If the condition holds, jump back to the body
    branch_if body_index, node: nil

    # Here we are at the point where the condition didn't hold anymore.
    # We must convert `nil` to whatever while's type is.
    upcast node.body, @context.program.nil_type, node.type

    # Otherwise we are at the end of the while.
    # Any `break` that happened leads us here
    while_breaks.each do |while_break|
      patch_jump(while_break)
    end

    unless @wants_value
      pop aligned_sizeof_type(node), node: nil
    end

    @while = old_while
    @while_breaks = old_while_breaks
    @while_nexts = old_while_nexts

    false
  end

  def visit(node : Return)
    raise_if_wants_struct_pointer(node)

    exp = node.exp

    exp_type =
      if exp
        request_value(exp)
        exp.type
      else
        put_nil node: node
        @context.program.nil_type
      end

    def_type = @def.not_nil!.type

    compiled_block = @compiled_block
    if compiled_block
      def_type = merge_block_break_type(def_type, compiled_block.block)
    end

    upcast node, exp_type, def_type

    if @compiling_block
      leave_def aligned_sizeof_type(def_type), node: node
    else
      leave aligned_sizeof_type(def_type), node: node
    end

    false
  end

  def visit(node : TypeOf)
    return false unless @wants_value

    put_type node.type, node: node
    false
  end

  def visit(node : SizeOf)
    return false unless @wants_value

    put_i32 inner_sizeof_type(node.exp), node: node

    false
  end

  def visit(node : Path)
    return false unless @wants_value

    if const = node.target_const
      if const.value.simple_literal?
        const.value.accept self
      elsif const == @context.program.argc
        argc_unsafe(node: node)
      elsif const == @context.program.argv
        argv_unsafe(node: node)
      else
        index = initialize_const_if_needed(const)
        if @wants_struct_pointer
          push_zeros(aligned_sizeof_type(const.value), node: nil)
          get_const_pointer index, node: node
        else
          get_const index, aligned_sizeof_type(const.value), node: node
        end
      end
    elsif replacement = node.syntax_replacement
      replacement.accept self
    else
      put_type node.type, node: node
    end
    false
  end

  private def get_const_index_and_compiled_def(const : Const) : {Int32, CompiledDef}
    index_and_compiled_def = @context.const_index_and_compiled_def?(const)
    return index_and_compiled_def if index_and_compiled_def

    value = const.value
    value = @context.program.cleanup(value)

    fake_def = const.fake_def.not_nil!
    fake_def.owner = const.visitor.not_nil!.current_type
    fake_def.body = value
    fake_def.bind_to(value)

    compiled_def = CompiledDef.new(@context, fake_def, fake_def.owner, 0)

    declare_local_vars(fake_def, compiled_def.local_vars)

    compiler = Compiler.new(@context, compiled_def, top_level: true)
    compiler.compile_def(fake_def)

    {% if Debug::DECOMPILE %}
      puts "=== #{const} ==="
      puts Disassembler.disassemble(@context, compiled_def)
      puts "=== #{const} ==="
    {% end %}

    {@context.declare_const(const, compiled_def), compiled_def}
  end

  def visit(node : Generic)
    return false unless @wants_value

    put_type node.type, node: node
    false
  end

  def visit(node : PointerOf)
    return false unless @wants_value

    exp = node.exp
    case exp
    when Var
      local_var = lookup_closured_var_or_local_var(exp.name)
      case local_var
      in LocalVar
        index, type = local_var.index, local_var.type
        pointerof_var(index, node: node)
      in ClosuredVar
        node.raise "BUG: missing interpter pointerof closured var"
      end
    when InstanceVar
      compile_pointerof_ivar(node, exp.name)
    when ClassVar
      compile_pointerof_class_var(node, exp)
    when ReadInstanceVar
      # TODO: check struct
      exp.obj.accept self

      type = exp.obj.type

      if type.passed_by_value?
        node.raise "BUG: missing interpret for PointerOf with exp #{exp.class} for a pass-by-value"
      end

      ivar_offset = ivar_offset(type, exp.name)
      ivar_size = inner_sizeof_type(type.lookup_instance_var(exp.name))

      # At this point, at least for class types, we have a pointer on the stack,
      # so we just need to offset it
      put_i32 ivar_offset, node: nil
      pointer_add 1, node: node
    else
      node.raise "BUG: missing interpret for PointerOf with exp #{exp.class}"
    end
    false
  end

  private def compile_pointerof_ivar(node : ASTNode, name : String)
    index = scope.index_of_instance_var(name).not_nil!
    if scope.struct?
      pointerof_ivar(@context.offset_of(scope, index), node: node)
    else
      pointerof_ivar(@context.instance_offset_of(scope, index), node: node)
    end
  end

  private def compile_pointerof_class_var(node : ASTNode, exp : ClassVar)
    index, compiled_def = class_var_index_and_compiled_def(exp)

    if compiled_def
      initialize_class_var_if_needed(exp.var, index, compiled_def)
    end

    pointerof_class_var(index, node: node)
  end

  def visit(node : Not)
    exp = node.exp
    exp.accept self
    return false unless @wants_value

    value_to_bool(exp, exp.type)
    logical_not node: node

    false
  end

  def visit(node : Cast)
    raise_if_wants_struct_pointer(node)

    node.obj.accept self

    obj_type = node.obj.type
    to_type = node.to.type.virtual_type

    # TODO: check the proper conditions in codegen
    if obj_type == to_type
      # TODO: not tested
      nop
    elsif obj_type.pointer? && to_type.pointer?
      # Cast between pointers is nop
      nop
    elsif obj_type.pointer? && to_type.reference_like?
      # Cast from pointer to reference is nop
      nop
    elsif obj_type.reference_like? && to_type.is_a?(PointerInstanceType)
      # Cast from reference to pointer is nop
      nop
    elsif node.upcast?
      upcast node, obj_type, to_type
    else
      # Check if obj is a `to_type`
      dup aligned_sizeof_type(node.obj), node: nil
      is_a(node, obj_type, to_type)

      # If so, branch
      branch_if 0, node: nil
      cond_jump_location = patch_location

      # Otherwise we need to raise
      # TODO: actually raise
      unreachable "BUG: missing handling of `.as(...)` when it fails", node: nil

      patch_jump(cond_jump_location)
      downcast node.obj, obj_type, to_type
    end

    false
  end

  def visit(node : NilableCast)
    # TODO: not tested
    node.obj.accept self

    obj_type = node.obj.type
    to_type = node.to.type.virtual_type

    # TODO: check the proper conditions in codegen
    if obj_type == to_type
      nop
    else
      # Check if obj is a `to_type`
      dup aligned_sizeof_type(node.obj), node: nil
      is_a(node, obj_type, to_type)

      # If so, branch
      branch_if 0, node: nil
      cond_jump_location = patch_location

      # Otherwise it's nil
      put_nil node: nil
      pop aligned_sizeof_type(node.obj), node: nil
      upcast node.obj, @context.program.nil_type, node.type
      jump 0, node: nil
      otherwise_jump_location = patch_location

      patch_jump(cond_jump_location)
      downcast node.obj, obj_type, to_type
      upcast node.obj, to_type, node.type

      patch_jump(otherwise_jump_location)
    end

    false
  end

  def visit(node : IsA)
    node.obj.accept self
    return false unless @wants_value

    obj_type = node.obj.type
    const_type = node.const.type

    is_a(node, obj_type, const_type)

    false
  end

  def visit(node : RespondsTo)
    node.obj.accept self
    return false unless @wants_value

    obj_type = node.obj.type

    responds_to(node, obj_type, node.name)

    false
  end

  private def is_a(node : ASTNode, type : Type, target_type : Type)
    type = type.remove_indirection
    filtered_type = type.filter_by(target_type).not_nil!

    filter_type(node, type, target_type)
  end

  private def responds_to(node : ASTNode, type : Type, name : String)
    type = type.remove_indirection
    filtered_type = type.filter_by_responds_to(name).not_nil!

    filter_type(node, type, filtered_type)
  end

  private def filter_type(node : ASTNode, type : Type, filtered_type : Type)
    if type == filtered_type
      # TODO: not tested
      pop aligned_sizeof_type(type), node: nil
      put_true node: nil
      return
    end

    case type
    when VirtualType
      reference_is_a(type_id(filtered_type), node: node)
    when MixedUnionType
      union_is_a(aligned_sizeof_type(type), type_id(filtered_type), node: node)
    when NilableType
      if filtered_type.nil_type?
        pointer_is_null(node: node)
      else
        pointer_is_not_null(node: node)
      end
    when NilableReferenceUnionType
      if filtered_type.nil_type?
        # TODO: not tested
        pointer_is_null(node: node)
      else
        # TODO: maybe missing checking against another reference union type?
        reference_is_a(type_id(filtered_type), node: node)
      end
    when ReferenceUnionType
      case filtered_type
      when NonGenericClassType
        reference_is_a(type_id(filtered_type), node: node)
      when GenericClassInstanceType
        # TODO: not tested
        reference_is_a(type_id(filtered_type), node: node)
      when VirtualType
        # TODO: not tested
        reference_is_a(type_id(filtered_type), node: node)
      else
        node.raise "BUG: missing IsA from #{type} to #{filtered_type} (#{type.class} to #{filtered_type.class})"
      end
    else
      node.raise "BUG: missing IsA from #{type} to #{filtered_type} (#{type.class} to #{filtered_type.class})"
    end
  end

  def visit(node : Call)
    obj = node.obj

    target_defs = node.target_defs
    unless target_defs
      node.raise "BUG: no target defs"
    end

    if target_defs.size == 1
      target_def = target_defs.first
    else
      target_def = Multidispatch.create_def(@context, node, target_defs)
    end

    body = target_def.body
    if body.is_a?(Primitive)
      visit_primitive(node, body)
      return false
    end

    if body.is_a?(InstanceVar)
      # Inline the call, so that it also works fine when wanting to take a pointer through things
      # (this is how the read Crystal works too
      if obj
        compile_read_instance_var(node, obj, body.name)
      else
        compile_instance_var(body)
      end

      # We still have to accept the call arguments, but discard their values
      node.args.each { |arg| discard_value(arg) }
      node.named_args.try &.each { |arg| discard_value(arg.value) }

      return false
    end

    if obj && (obj_type = obj.type).is_a?(LibType)
      compile_lib_call(node, obj_type)
      return false
    end

    compiled_def = @context.defs[target_def]? ||
                   begin
                     create_compiled_def(node, target_def)
                   rescue ex : Crystal::TypeException
                     node.raise ex, inner: ex
                   end

    pop_obj = dont_request_struct_pointer do
      compile_call_args(node, target_def)
    end

    if (block = node.block) && !block.fun_literal
      call_with_block compiled_def, node: node
    else
      call compiled_def, node: node
    end

    if @wants_value
      # Pop the struct that's on the stack, if any, if obj was a struct
      # (but the struct is after the call's value, so we must
      # remove it past that value)
      pop_from_offset aligned_sizeof_type(pop_obj), aligned_sizeof_type(node), node: nil if pop_obj
      put_stack_top_pointer_if_needed(node)
    else
      if pop_obj
        pop aligned_sizeof_type(node) + aligned_sizeof_type(pop_obj), node: nil
      else
        pop aligned_sizeof_type(node), node: nil
      end
    end

    false
  end

  private def compile_lib_call(node : Call, obj_type)
    target_def = node.target_def
    external = target_def.as(External)

    args_bytesizes = [] of Int32
    args_ffi_types = [] of FFI::Type
    proc_args = [] of FFI::CallInterface?

    dont_request_struct_pointer do
      node.args.each_with_index do |arg, i|
        arg_type = arg.type

        if arg.is_a?(NilLiteral)
          # Nil is used to mean Pointer.null
          put_i64 0, node: arg
        else
          request_value(arg)
        end
        # TODO: upcast?

        if arg_type.is_a?(ProcInstanceType)
          args_bytesizes << aligned_sizeof_type(arg)
          args_ffi_types << FFI::Type.pointer

          # We need to use the type in the lib fun definition
          external_arg = external.args[i]
          proc_args << external_arg.type.as(ProcInstanceType).ffi_call_interface
        else
          case arg
          when NilLiteral
            args_bytesizes << sizeof(Pointer(Void))
            args_ffi_types << FFI::Type.pointer
          when Out
            # TODO: this out handling is bad. Why is out's type not a pointer already?
            args_bytesizes << sizeof(Pointer(Void))
            args_ffi_types << FFI::Type.pointer
          else
            args_bytesizes << aligned_sizeof_type(arg)
            args_ffi_types << arg.type.ffi_type
          end
          proc_args << nil
        end
      end
    end

    if node.named_args
      node.raise "BUG: missing lib call with named args"
    end

    if external.varargs?
      lib_function = LibFunction.new(
        def: external,
        symbol: @context.c_function(obj_type, external.real_name),
        call_interface: FFI::CallInterface.variadic(
          abi: FFI::ABI::DEFAULT,
          args: args_ffi_types,
          return_type: external.type.ffi_type,
          fixed_args: external.args.size,
          total_args: node.args.size,
        ),
        args_bytesizes: args_bytesizes,
        proc_args: proc_args,
      )
      @context.add_gc_reference(lib_function)
    else
      lib_function = @context.lib_functions[external] ||= LibFunction.new(
        def: external,
        symbol: @context.c_function(obj_type, external.real_name),
        call_interface: FFI::CallInterface.new(
          abi: FFI::ABI::DEFAULT,
          args: args_ffi_types,
          return_type: external.type.ffi_type,
        ),
        args_bytesizes: args_bytesizes,
        proc_args: proc_args,
      )
    end

    lib_call(lib_function, node: node)

    if @wants_value
      put_stack_top_pointer_if_needed(node)
    else
      pop aligned_sizeof_type(node), node: nil
    end

    return false
  end

  private def create_compiled_def(node : Call, target_def : Def)
    block = node.block
    block = nil if block && !block.visited? && !block.fun_literal

    # Compile the block too if there's one
    if block && !block.fun_literal
      compiled_block = create_compiled_block(block, target_def)
    end

    args_bytesize = 0

    obj = node.obj
    args = node.args
    named_args = node.named_args
    obj_type = obj.try(&.type) || target_def.owner

    if obj_type == @context.program
      # Nothing
    elsif obj_type.passed_by_value?
      args_bytesize += sizeof(Pointer(UInt8))
    else
      args_bytesize += aligned_sizeof_type(obj_type)
    end

    i = 0

    # This is the case of a multidispatch with an explicit "self" being passed
    i += 1 if target_def.args.first?.try &.name == "self"

    args.each do
      target_def_arg = target_def.args[i]
      target_def_var_type = target_def.vars.not_nil![target_def_arg.name].type
      args_bytesize += aligned_sizeof_type(target_def_var_type)

      i += 1
    end

    named_args.try &.each do
      target_def_arg = target_def.args[i]
      target_def_var_type = target_def.vars.not_nil![target_def_arg.name].type
      args_bytesize += aligned_sizeof_type(target_def_var_type)

      i += 1
    end

    # If the block is captured there's an extra argument
    if block && block.fun_literal
      args_bytesize += sizeof(Proc(Void))
    end

    # See line 19 in codegen call
    owner = node.super? ? node.scope : target_def.owner

    compiled_def = CompiledDef.new(@context, target_def, owner, args_bytesize)

    # We don't cache defs that yield because we inline the block's contents
    if block
      @context.add_gc_reference(compiled_def)
    else
      @context.defs[target_def] = compiled_def
    end

    declare_local_vars(target_def, compiled_def.local_vars)

    compiler = Compiler.new(@context, compiled_def, top_level: false)
    compiler.compiled_block = compiled_block

    begin
      compiler.compile_def(target_def)
    rescue ex : Crystal::CodeError
      node.raise "compiling #{node}", inner: ex
    end

    {% if Debug::DECOMPILE %}
      puts "=== #{target_def.owner}##{target_def.name} ==="
      puts compiled_def.local_vars
      puts Disassembler.disassemble(@context, compiled_def)
      puts "=== #{target_def.owner}##{target_def.name} ==="
    {% end %}

    compiled_def
  end

  private def create_compiled_block(block : Block, target_def : Def)
    bytesize_before_block_local_vars = @local_vars.current_bytesize

    @local_vars.push_block

    begin
      needs_closure_context = false

      block.vars.try &.each do |name, var|
        var_type = var.type?
        next unless var_type

        if var.closure_in?(block)
          needs_closure_context = true
        end

        next if var.context != block

        @local_vars.declare(name, var_type)
      end

      if needs_closure_context
        @local_vars.declare(Closure::VAR_NAME, @context.program.pointer_of(@context.program.void))
      end

      bytesize_after_block_local_vars = @local_vars.current_bytesize

      block_args_bytesize = block.args.sum { |arg| aligned_sizeof_type(arg) }

      compiled_block = CompiledBlock.new(block, @local_vars,
        args_bytesize: block_args_bytesize,
        locals_bytesize_start: bytesize_before_block_local_vars,
        locals_bytesize_end: bytesize_after_block_local_vars,
      )

      # Store it so the GC doesn't collect it (it's in the instructions but it might not be aligned)
      @context.add_gc_reference(compiled_block)

      compiler = Compiler.new(@context, @local_vars,
        instructions: compiled_block.instructions,
        scope: @scope, def: @def, top_level: false)
      compiler.compiled_block = @compiled_block
      compiler.block_level = block_level + 1

      compiler.compile_block(block, target_def, @closure_context)

      {% if Debug::DECOMPILE %}
        puts "=== #{target_def.owner}##{target_def.name}#block ==="
        puts Disassembler.disassemble(@context, compiled_block.instructions, @local_vars)
        puts "=== #{target_def.owner}##{target_def.name}#block ==="
      {% end %}
    ensure
      @local_vars.pop_block
    end

    compiled_block
  end

  private def compile_call_args(node : Call, target_def : Def)
    # Self for structs is passed by reference
    pop_obj = nil

    obj = node.obj
    if obj
      if obj.type.passed_by_value?
        pop_obj = compile_struct_call_receiver(obj, target_def.owner)
      else
        request_value(obj)
      end
    else
      # Pass implicit self if needed
      put_self(node: node) unless node.scope.is_a?(Program)
    end

    target_def_args = target_def.args

    i = 0

    # This is the case of a multidispatch with an explicit "self" being passed
    i += 1 if target_def.args.first?.try &.name == "self"

    node.args.each do |arg|
      arg_type = arg.type
      target_def_arg = target_def_args[i]
      target_def_var_type = target_def.vars.not_nil![target_def_arg.name].type

      compile_call_arg(arg, arg_type, target_def_var_type)

      i += 1
    end

    node.named_args.try &.each do |n|
      arg = n.value
      arg_type = arg.type
      target_def_arg = target_def_args[i]
      target_def_var_type = target_def.vars.not_nil![target_def_arg.name].type

      compile_call_arg(arg, arg_type, target_def_var_type)

      i += 1
    end

    if fun_literal = node.block.try(&.fun_literal)
      request_value fun_literal
    end

    pop_obj
  end

  private def compile_call_arg(arg, arg_type, target_def_var_type)
    # Check autocasting from symbol to enum
    if arg.is_a?(SymbolLiteral) && target_def_var_type.is_a?(EnumType)
      symbol_name = arg.value.underscore
      target_def_var_type.types.each do |enum_name, enum_value|
        if enum_name.underscore == symbol_name
          request_value(enum_value.as(Const).value)
          return
        end
      end
    end

    if arg_type != target_def_var_type && arg.is_a?(NumberLiteral)
      case target_def_var_type
      when IntegerType
        # Autocast to integer
        compile_number(arg, target_def_var_type.kind, arg.value)
        return
      when FloatType
        # Autocast to float
        compile_number(arg, target_def_var_type.kind, arg.value)
        return
      end
    end

    request_value(arg)

    # We need to cast the argument to the target_def variable
    # corresponding to the argument. If for example we have this:
    #
    # ```
    # def foo(x : Int32)
    #   x = nil
    # end
    #
    # foo(1)
    # ```
    #
    # Then the actual type of `x` inside `foo` is (Int32 | Nil),
    # and we must cast `1` to it.
    upcast arg, arg_type, target_def_var_type
  end

  private def compile_struct_call_receiver(obj : ASTNode, owner : Type)
    case obj
    when Var
      if obj.name == "self"
        self_type = @def.not_nil!.vars.not_nil!["self"].type
        if self_type == owner
          put_self(node: obj)
        else
          # It might happen that self's type was narrowed down,
          # so we need to accept it regularly and downcast it.
          # TODO: how to handle needs_struct_pointer?
          request_value(obj)

          # Then take a pointer to it (this is self inside the method)
          put_stack_top_pointer(aligned_sizeof_type(obj), node: nil)

          # We must remember to later pop the struct that's still on the stack
          pop_obj = obj
        end
      else
        local_var = lookup_closured_var_or_local_var(obj.name)
        case local_var
        in LocalVar
          ptr_index, var_type = local_var.index, local_var.type
          if obj.type == var_type
            pointerof_var(ptr_index, node: obj)
          elsif var_type.is_a?(MixedUnionType) && obj.type.struct?
            # Get pointer of var
            pointerof_var(ptr_index, node: obj)

            # Add 8 to it, to reach the union value
            put_i64 8_i64, node: nil
            pointer_add 1_i64, node: nil
          elsif var_type.is_a?(MixedUnionType) && obj.type.is_a?(MixedUnionType)
            pointerof_var(ptr_index, node: obj)
          else
            obj.raise "BUG: missing call receiver by value cast from #{var_type} to #{obj.type} (#{var_type.class} to #{obj.type.class})"
          end
        in ClosuredVar
          obj.raise "BUG: missing interpter struct call receiver with closured var"
        end
      end
    when InstanceVar
      compile_pointerof_ivar(obj, obj.name)
    when ClassVar
      compile_pointerof_class_var(obj, obj)
    when Path
      const = obj.target_const.not_nil!
      index = initialize_const_if_needed(const)
      get_const_pointer index, node: obj
    else
      if needs_struct_pointer?(obj.type)
        request_struct_pointer(obj)
      else
        # For a struct, we first put it on the stack
        request_value(obj)

        # Then take a pointer to it (this is self inside the method)
        put_stack_top_pointer(aligned_sizeof_type(obj), node: nil)
      end

      # We must remember to later pop the struct that's still on the stack
      pop_obj = obj
    end

    pop_obj
  end

  private def declare_local_vars(vars_owner, local_vars : LocalVars, owner = vars_owner)
    needs_closure_context = false

    vars_owner.vars.try &.each do |name, var|
      var_type = var.type?
      next unless var_type

      # TODO (optimization): don't declare local var if it's closured,
      # but we need to be careful to support def args being closured
      if var.closure_in?(owner)
        needs_closure_context = true
      end

      local_vars.declare(name, var_type)
    end

    needs_closure_context ||= owner.is_a?(Def) && owner.self_closured?

    if needs_closure_context
      local_vars.declare(Closure::VAR_NAME, @context.program.pointer_of(@context.program.void))
    end
  end

  private def initialize_const_if_needed(const)
    index, compiled_def = get_const_index_and_compiled_def const

    # Do this:
    #
    # ```
    # unless const_initialized(index)
    #   call const_initializer
    #   set_const index
    # end
    # ```

    # This is `unless const_initialized(index)`
    const_initialized index, node: nil
    branch_if 0, node: nil
    cond_jump_location = patch_location

    # Now we are on the `then` branch
    call compiled_def, node: nil
    set_const index, aligned_sizeof_type(const.value), node: nil

    # Here we are outside of the unless
    patch_jump(cond_jump_location)

    index
  end

  private def initialize_class_var_if_needed(var, index, compiled_def)
    # Do this:
    #
    # ```
    # unless class_var_initialized(index)
    #   call class_var_initializer
    #   set_class_var index
    # end
    # ```

    # This is `unless class_var_initialized(index)`
    class_var_initialized index, node: nil
    branch_if 0, node: nil
    cond_jump_location = patch_location

    # Now we are on the `then` branch
    call compiled_def, node: nil
    set_class_var index, aligned_sizeof_type(var), node: nil

    # Here we are outside of the unless
    patch_jump(cond_jump_location)

    index
  end

  private def accept_call_members(node : Call)
    dont_request_struct_pointer do
      if obj = node.obj
        obj.accept(self)
      else
        put_self(node: node) unless scope.is_a?(Program)
      end

      node.args.each &.accept(self)
      node.named_args.try &.each &.value.accept(self)
    end
  end

  def visit(node : Out)
    case exp = node.exp
    when Var
      local_var = lookup_closured_var_or_local_var(exp.name)
      case local_var
      in LocalVar
        index, type = local_var.index, local_var.type
        pointerof_var(index, node: node)
      in ClosuredVar
        node.raise "BUG: missing interpter out closured var"
      end
    when InstanceVar
      compile_pointerof_ivar(node, exp.name)
    when Underscore
      node.raise "BUG: missing interpret out with underscore"
      # Nothing to do
    else
      node.raise "BUG: unexpected out exp: #{exp}"
    end

    false
  end

  def visit(node : ProcLiteral)
    is_closure = node.def.closure?

    # TODO: This was copied from Codegen. Why is it not in CleanupTransformer?
    # If we don't care about a proc literal's return type then we mark the associated
    # def as returning void. This can't be done in the type inference phase because
    # of bindings and type propagation.
    if node.force_nil?
      node.def.set_type @context.program.nil
    else
      # Use proc literal's type, which might have a broader type then the body
      # (for example, return type: Int32 | String, body: String)
      node.def.set_type node.return_type
    end

    target_def = node.def
    target_def.owner = @context.program
    args = target_def.args

    # 1. Compile def
    args_bytesize = args.sum { |arg| aligned_sizeof_type(arg) }
    args_bytesize += sizeof(Void*) if is_closure

    compiled_def = CompiledDef.new(@context, target_def, target_def.owner, args_bytesize)

    # 2. Store it in context
    @context.add_gc_reference(compiled_def)

    # Declare local variables for the newly compiled function

    # First declare the proc arguments, so that the order matches the call
    target_def.args.each do |arg|
      var = target_def.vars.not_nil![arg.name]
      var_type = var.type?
      next unless var_type

      compiled_def.local_vars.declare(arg.name, var_type)
    end

    a_def = @def

    needs_closure_context = (target_def.vars.try &.any? { |name, var| var.type? && var.closure_in?(target_def) })

    # Declare the closure context arg and var, if any
    if is_closure || needs_closure_context
      if is_closure && needs_closure_context
        compiled_def.local_vars.declare(Closure::ARG_NAME, @context.program.pointer_of(@context.program.void))
      end

      compiled_def.local_vars.declare(Closure::VAR_NAME, @context.program.pointer_of(@context.program.void))
    end

    # Then declare all variables
    target_def.vars.try &.each do |name, var|
      var_type = var.type?
      next unless var_type

      if var.closure_in?(target_def)
        needs_closure_context = true
      end

      # Skip arg because it was already declared above
      next if target_def.args.any? { |arg| arg.name == name }

      # TODO: closures!
      next if var.context != target_def

      compiled_def.local_vars.declare(name, var_type)
    end

    compiler = Compiler.new(@context, compiled_def, top_level: false)
    begin
      compiler.compile_def(target_def, is_closure ? @closure_context : nil)
    rescue ex : Crystal::CodeError
      node.raise "compiling #{node}", inner: ex
    end

    {% if Debug::DECOMPILE %}
      puts "=== ProcLiteral ==="
      puts compiled_def.local_vars
      puts Disassembler.disassemble(@context, compiled_def)
      puts "=== ProcLiteral ==="
    {% end %}

    # 3. Push compiled_def id to stack
    put_i64 compiled_def.object_id.to_i64!, node: node

    # 4. Push closure context to stack
    if @closure_context
      # If it's a closure, we push the pointer that holds the closure data
      closure_var_index = get_closure_var_index
      get_local closure_var_index, sizeof(Void*), node: node
    else
      # Otherwise, it's a null pointer
      put_i64 0, node: node
    end

    false
  end

  def visit(node : Break)
    raise_if_wants_struct_pointer(node)

    exp = node.exp

    exp_type =
      if exp
        request_value(exp)
        exp.type
      else
        put_nil node: node

        @context.program.nil_type
      end

    if target_while = @while
      target_while = @while.not_nil!

      upcast node, exp_type, target_while.type

      jump 0, node: nil
      @while_breaks.not_nil! << patch_location
    elsif compiling_block = @compiling_block
      block = compiling_block.block
      target_def = compiling_block.target_def

      final_type = merge_block_break_type(target_def.type, block)

      upcast node, exp_type, final_type

      break_block aligned_sizeof_type(final_type), node: node
    else
      node.raise "BUG: break without target while or block"
    end

    false
  end

  def visit(node : Next)
    raise_if_wants_struct_pointer(node)

    exp = node.exp

    if @while
      if exp
        discard_value(exp)
      else
        put_nil node: node
      end

      jump 0, node: nil
      @while_nexts.not_nil! << patch_location
    elsif compiling_block = @compiling_block
      exp_type =
        if exp
          request_value(exp)
          exp.type
        else
          put_nil node: node
          @context.program.nil_type
        end

      upcast node, exp_type, compiling_block.block.type
      leave aligned_sizeof_type(compiling_block.block.type), node: node
    else
      node.raise "BUG: next without target while or block"
    end

    false
  end

  def visit(node : Yield)
    compiled_block = @compiled_block.not_nil!
    block = compiled_block.block

    splat_index = block.splat_index
    if splat_index
      node.raise "BUG: block with splat not yet supported"
    end

    if node.exps.any?(Splat)
      node.raise "BUG: splat inside yield not yet supported"
    end

    pop_obj = nil

    # Check if tuple unpacking is needed
    if node.exps.size == 1 &&
       (tuple_type = node.exps.first.type).is_a?(TupleInstanceType) &&
       block.args.size > 1
      # Accept the tuple
      exp = node.exps.first
      dont_request_struct_pointer do
        request_value exp
      end

      # We need to cast to the block var, not arg
      # (the var might have more types in it if it's assigned other values)
      block_var_types = block.args.map do |arg|
        block.vars.not_nil![arg.name].type
      end

      unpack_tuple exp, tuple_type, block_var_types

      # We need to discard the tuple value that comes before the unpacked values
      pop_obj = tuple_type
    else
      node.exps.each_with_index do |exp, i|
        if i < block.args.size
          dont_request_struct_pointer do
            request_value(exp)
          end

          # We need to cast to the block var, not arg
          # (the var might have more types in it if it's assigned other values)
          block_arg = block.args[i]
          block_var = block.vars.not_nil![block_arg.name]

          upcast exp, exp.type, block_var.type
        else
          discard_value(exp)
        end
      end
    end

    call_block compiled_block, node: node

    if @wants_value
      pop_from_offset aligned_sizeof_type(pop_obj), aligned_sizeof_type(node), node: nil if pop_obj
      put_stack_top_pointer_if_needed(node)
    else
      if pop_obj
        pop aligned_sizeof_type(node) + aligned_sizeof_type(pop_obj), node: nil
      else
        pop aligned_sizeof_type(node), node: nil
      end
    end

    false
  end

  def visit(node : ClassDef)
    # TODO: change scope
    discard_value node.body

    return false unless @wants_value

    put_nil(node: node)
    false
  end

  def visit(node : ModuleDef)
    # TODO: change scope
    discard_value node.body

    return false unless @wants_value

    put_nil(node: node)
    false
  end

  def visit(node : EnumDef)
    # TODO: visit body?
    false
  end

  def visit(node : Def)
    false
  end

  def visit(node : FunDef)
    false
  end

  def visit(node : LibDef)
    false
  end

  def visit(node : Macro)
    false
  end

  def visit(node : VisibilityModifier)
    node.exp.accept self
    false
  end

  def visit(node : Annotation)
    false
  end

  def visit(node : AnnotationDef)
    false
  end

  def visit(node : TypeDeclaration)
    false
  end

  def visit(node : Alias)
    false
  end

  def visit(node : Include)
    false
  end

  def visit(node : Extend)
    false
  end

  def visit(node : Unreachable)
    unreachable("Reached the unreachable", node: node)

    false
  end

  def visit(node : FileNode)
    file_module = @context.program.file_module(node.filename)

    a_def = Def.new(node.filename)
    a_def.body = node.node
    a_def.owner = @context.program
    a_def.type = @context.program.nil_type
    a_def.vars = file_module.vars

    compiled_def = CompiledDef.new(@context, a_def, a_def.owner, 0)

    declare_local_vars(file_module, compiled_def.local_vars)

    compiler = Compiler.new(@context, compiled_def, top_level: true)
    compiler.compile_def(a_def, closure_owner: file_module)

    @context.add_gc_reference(compiled_def)

    {% if Debug::DECOMPILE %}
      puts "=== #{node.filename} ==="
      puts Disassembler.disassemble(@context, compiled_def)
      puts "=== #{node.filename} ==="
    {% end %}

    call compiled_def, node: node
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
  end

  # This is where we define one method per instruction/opcode.
  {% for name, instruction in Crystal::Repl::Instructions %}
    {% operands = instruction[:operands] %}

    def {{name.id}}(
      {% if operands.empty? %}
        *, node : ASTNode?
      {% else %}
        {{*operands}}, *, node : ASTNode?
      {% end %}
    ) : Nil
      @instructions.nodes[instructions_index] = node if node

      append OpCode::{{ name.id.upcase }}
      {% for operand in operands %}
        append {{operand.var}}
      {% end %}
    end
  {% end %}

  private def request_value(node : ASTNode)
    accept_with_wants_value node, true
  end

  private def discard_value(node : ASTNode)
    dont_request_struct_pointer do
      accept_with_wants_value node, false
    end
  end

  private def accept_with_wants_value(node : ASTNode, wants_value)
    old_wants_value = @wants_value
    @wants_value = wants_value
    node.accept self
    @wants_value = old_wants_value
  end

  private def request_struct_pointer(node : ASTNode)
    old_wants_stuct_pointer = @wants_struct_pointer
    @wants_struct_pointer = true
    request_value node
    @wants_struct_pointer = old_wants_stuct_pointer
  end

  private def dont_request_struct_pointer
    old_wants_stuct_pointer = @wants_struct_pointer
    @wants_struct_pointer = false
    value = yield
    @wants_struct_pointer = old_wants_stuct_pointer
    value
  end

  private def put_stack_top_pointer_if_needed(value)
    if @wants_struct_pointer
      put_stack_top_pointer(aligned_sizeof_type(value), node: nil)
    end
  end

  private def raise_if_wants_struct_pointer(node : ASTNode, body : Primitive)
    # We'll slowly handle these cases, but they are probably very uncommon.
    # We still want to know where they happen!
    if @wants_struct_pointer
      node.raise "BUG: missing handling of @wants_struct_pointer for #{body}"
    end
  end

  private def raise_if_wants_struct_pointer(node : ASTNode)
    # We'll slowly handle these cases, but they are probably very uncommon.
    # We still want to know where they happen!
    if @wants_struct_pointer
      node.raise "BUG: missing handling of @wants_struct_pointer for #{node.class}"
    end
  end

  # TODO: block.break shouldn't exist: the type should be merged in target_def
  private def merge_block_break_type(def_type : Type, block : Block)
    block_break_type = block.break.type?
    if block_break_type
      @context.program.type_merge([def_type, block_break_type] of Type) ||
        @context.program.no_return
    else
      def_type
    end
  end

  private def put_true(*, node : ASTNode?)
    put_i64 1_i64, node: node
  end

  private def put_false(*, node : ASTNode?)
    put_i64 0_i64, node: node
  end

  private def put_i8(value : Int8, *, node : ASTNode?)
    put_i64 value.to_i64!, node: node
  end

  private def put_u8(value : UInt8, *, node : ASTNode?)
    put_i64 value.to_u64!.to_i64!, node: node
  end

  private def put_i16(value : Int16, *, node : ASTNode?)
    put_i64 value.to_i64!, node: node
  end

  private def put_u16(value : UInt16, *, node : ASTNode?)
    put_i64 value.to_u64!.to_i64!, node: node
  end

  private def put_i32(value : Int32, *, node : ASTNode?)
    put_i64 value.to_i64!, node: node
  end

  private def put_u32(value : UInt32, *, node : ASTNode?)
    put_i64 value.to_u64!.to_i64!, node: node
  end

  private def put_u64(value : UInt64, *, node : ASTNode?)
    put_i64 value.to_i64!, node: node
  end

  private def put_type(type : Type, *, node : ASTNode?)
    put_i32 type_id(type), node: node
  end

  private def put_def(a_def : Def)
  end

  private def put_self(*, node : ASTNode)
    closured_self = lookup_closured_var?("self")
    if closured_self
      read_from_closured_var(closured_self, node: node)
      return
    end

    if scope.struct?
      if scope.passed_by_value?
        get_local 0, sizeof(Pointer(UInt8)), node: node
      else
        get_local 0, aligned_sizeof_type(scope), node: node
      end
    else
      get_local 0, sizeof(Pointer(UInt8)), node: node
    end
  end

  private def append(op_code : OpCode)
    append op_code.value
  end

  private def append(a_def : CompiledDef)
    append(a_def.object_id.unsafe_as(Int64))
  end

  private def append(a_block : CompiledBlock)
    append(a_block.object_id.unsafe_as(Int64))
  end

  private def append(lib_function : LibFunction)
    append(lib_function.object_id.unsafe_as(Int64))
  end

  private def append(call : Call)
    append(call.object_id.unsafe_as(Int64))
  end

  private def append(string : String)
    append(string.object_id.unsafe_as(Int64))
  end

  private def append(value : Int64)
    value.unsafe_as(StaticArray(UInt8, 8)).each do |byte|
      append byte
    end
  end

  private def append(value : Int32)
    value.unsafe_as(StaticArray(UInt8, 4)).each do |byte|
      append byte
    end
  end

  private def append(value : Int16)
    value.unsafe_as(StaticArray(UInt8, 2)).each do |byte|
      append byte
    end
  end

  private def append(value : Int8)
    append value.unsafe_as(UInt8)
  end

  private def append(value : Symbol)
    value.unsafe_as(StaticArray(UInt8, 4)).each do |byte|
      append byte
    end
  end

  private def append(value : UInt8)
    @instructions.instructions << value
  end

  # Many times we need to jump or branch to an instruction for which we don't
  # know the offset/index yet.
  # In those cases we generate a jump to zero, but remember where that "zero"
  # is in the bytecode. Once we know where we have to jump, we modify the
  # bytecode to patch it with the correct jump offset.
  private def patch_jump(offset : Int32)
    (@instructions.instructions.to_unsafe + offset).as(Int32*).value = instructions_index
  end

  # After we emit bytecode for a branch or jump, the last four bytes
  # are always for the jump offset.
  private def patch_location
    instructions_index - 4
  end

  private def instructions_index
    @instructions.instructions.size
  end

  private def aligned_sizeof_type(node : ASTNode) : Int32
    @context.aligned_sizeof_type(node)
  end

  private def aligned_sizeof_type(type : Type) : Int32
    @context.aligned_sizeof_type(type)
  end

  private def inner_sizeof_type(node : ASTNode) : Int32
    @context.inner_sizeof_type(node)
  end

  private def inner_sizeof_type(type : Type) : Int32
    @context.inner_sizeof_type(type)
  end

  private def aligned_instance_sizeof_type(type : Type) : Int32
    @context.aligned_instance_sizeof_type(type)
  end

  private def ivar_offset(type : Type, name : String) : Int32
    if type.extern_union?
      0
    else
      @context.ivar_offset(type, name)
    end
  end

  private def type_id(type : Type)
    @context.type_id(type)
  end

  # The only types that we want to put a struct pointer for
  # (for @wants_struct_pointer) are mutable types that are not
  # inside a union. The reason is that if they are inside a union,
  # they are already copied, so passing a perfect pointer is useless.
  private def needs_struct_pointer?(type : Type)
    case type
    when PrimitiveType, PointerInstanceType, ProcInstanceType,
         TupleInstanceType, NamedTupleInstanceType, MixedUnionType
      false
    when StaticArrayInstanceType
      true
    when VirtualType
      type.struct?
    when NonGenericModuleType
      type.including_types.try { |t| needs_struct_pointer?(t) }
    when GenericModuleInstanceType
      type.including_types.try { |t| needs_struct_pointer?(t) }
    when GenericClassInstanceType
      needs_struct_pointer?(type.generic_type)
    when TypeDefType
      needs_struct_pointer?(type.typedef)
    when AliasType
      needs_struct_pointer?(type.aliased_type)
    when ClassType
      type.struct?
    else
      false
    end
  end

  private macro nop
  end
end

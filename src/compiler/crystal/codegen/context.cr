class Crystal::CodeGenVisitor < Crystal::Visitor
  class Context
    property :fun
    property type
    property vars
    property return_type
    property return_phi
    property break_phi
    property next_phi
    property while_block
    property while_exit_block
    property! block
    property! block_context
    property closure_vars
    property closure_type
    property closure_ptr
    property closure_skip_parent
    property closure_parent_context
    property closure_self

    def initialize(@fun, @type, @vars = LLVMVars.new)
      @closure_skip_parent = false
    end

    def block_returns?
      (block = @block) && (block_context = @block_context) && (block.returns? || (block.yields? && block_context.block_returns?))
    end

    def block_breaks?
      (block = @block) && (block_context = @block_context) && (block.breaks? || (block.yields? && block_context.block_breaks?))
    end

    def reset_closure
      @closure_vars = nil
      @closure_type = nil
      @closure_ptr = nil
      @closure_skip_parent = false
      @closure_parent_context = nil
      @closure_self = nil
    end

    def clone
      context = Context.new @fun, @type, @vars
      context.return_type = @return_type
      context.return_phi = @return_phi
      context.break_phi = @break_phi
      context.next_phi = @next_phi
      context.while_block = @while_block
      context.while_exit_block = @while_exit_block
      context.block = @block
      context.block_context = @block_context
      context.closure_vars = @closure_vars
      context.closure_type = @closure_type
      context.closure_ptr = @closure_ptr
      context.closure_skip_parent = @closure_skip_parent
      context.closure_parent_context = @closure_parent_context
      context.closure_self = @closure_self
      context
    end
  end

  def with_cloned_context(new_context = @context)
    with_context(new_context.clone) { |ctx| yield ctx }
  end

  def with_context(new_context)
    old_context = @context
    @context = new_context
    value = yield old_context
    @context = old_context
    value
  end
end

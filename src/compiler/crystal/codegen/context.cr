require "./codegen"

class Crystal::CodeGenVisitor
  class Context
    property fun : LLVM::Function
    property type : Type
    property vars : Hash(String, LLVMVar)
    property return_type : Type?
    property return_phi : Phi?
    property break_phi : Phi?
    property next_phi : Phi?
    property while_block : LLVM::BasicBlock?
    property while_exit_block : LLVM::BasicBlock?
    property! block : Block
    property! block_context : Context
    property closure_vars : Array(MetaVar)?
    property closure_type : LLVM::Type?
    property closure_ptr : LLVM::Value?
    property closure_skip_parent : Bool
    property closure_parent_context : Context?
    property closure_self : Type?

    def initialize(@fun, @type, @vars = LLVMVars.new)
      @closure_skip_parent = false
    end

    def block_context=(@block_context : Nil)
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
      if block = @block
        context.block = block
      end
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

class Crystal::CodeGenVisitor < Crystal::Visitor
  class Phi
    include LLVMBuilderHelper

    getter node
    getter count
    getter exit_block

    def self.open(codegen, node, needs_value = true)
      block = new codegen, node, needs_value
      yield block
      block.close
    end

    def initialize(@codegen, @node, @needs_value)
      @phi_table = @needs_value ? LLVM::PhiTable.new : nil
      @count = 0
    end

    def exit_block
      @exit_block ||= @codegen.new_block "exit"
    end

    def builder
      @codegen.builder
    end

    def llvm_typer
      @codegen.llvm_typer
    end

    def add_last(value, type)
      add value, type, true
    end

    def add(value, type : Nil, last = false)
      unreachable
    end

    def add(value, type : NoReturnType, last = false)
      unreachable
    end

    def add(value, type : Type, last = false)
      if @needs_value
        unless node.type.void?
          value = @codegen.upcast value, node.type, type
          @phi_table.not_nil!.add insert_block, value
        end
      end
      @count += 1
      if last && @count == 1
        # Don't create exit block for just one value
      else
        br exit_block
      end
    end

    def close
      if @exit_block
        position_at_end exit_block
      end
      if node.returns? || node.no_returns?
        unreachable
      else
        if @count == 0
          unreachable
        elsif @needs_value
          phi_table = @phi_table.not_nil!
          if phi_table.empty?
            # All branches are void or no return
            @codegen.last = llvm_nil
          else
            if @exit_block
              @codegen.last = phi llvm_arg_type(@node.type), phi_table
            else
              @codegen.last = phi_table.values.first
            end
          end
        else
          @codegen.last = llvm_nil
        end
      end
      @codegen.last
    end
  end
end

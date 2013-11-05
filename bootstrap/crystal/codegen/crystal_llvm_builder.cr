module Crystal
  class CrystalLLVMBuilder
    def initialize(@builder, @codegen)
      @end = false
    end

    def ret
      return if @end
      @builder.ret
      @end = true
    end

    def ret(value)
      return if @end
      @builder.ret(value)
      @end = true
    end

    def br(block)
      return if @end
      @builder.br(block)
      @end = true
    end

    def unreachable
      # if ENV["UNREACHABLE"] == "1"
      #   backtrace = caller.join("\n")
      #   msg = "Reached the unreachable!"
      #   msg << " (#{data})" if data
      #   msg << "\n#{backtrace}"
      #   @codegen.llvm_puts(msg)
      # end
      return if @end
      @builder.unreachable
      @end = true
    end

    def position_at_end(block)
      @builder.position_at_end block
      @end = false
    end

    macro self.forward(name)
      "
      def #{name}
        @builder.#{name}
      end
      "
    end

    macro self.forward(name, args)
      "
      def #{name}(#{args})
        @builder.#{name}(#{args})
      end
      "
    end

    macro self.forward(name, def_args, call_args)
      "
      def #{name}(#{def_args})
        @builder.#{name}(#{call_args})
      end
      "
    end

    macro self.forward_named(name, args)
      "
      def #{name}(#{args}, name = \"\")
        @builder.#{name}(#{args}, name)
      end
      "
    end

    forward insert_block
    forward cond, "cond, then_block, else_block"
    forward phi, "type, incoming_blocks, incoming_values, name = \"\"", "type, incoming_blocks, incoming_values, name"
    forward call, "func, args = [] of LibLLVM::ValueRef", "func, args"
    forward_named alloca, "type"
    forward store, "value, ptr"
    forward_named load, "ptr"
    forward_named malloc, "type"
    forward_named array_malloc, "type, value"
    forward_named gep, "value, indices"
    forward_named extract_value, "value, index"
    forward_named bit_cast, "value, type"
    forward_named si2fp, "value, type"
    forward_named ui2fp, "value, type"
    forward_named zext, "value, type"
    forward_named sext, "value, type"
    forward_named trunc, "value, type"
    forward_named fpext, "value, type"
    forward_named fptrunc, "value, type"
    forward_named fp2si, "value, type"
    forward_named fp2ui, "value, type"
    forward_named si2fp, "value, type"
    forward_named ui2fp, "value, type"
    forward_named int2ptr, "value, type"
    forward_named ptr2int, "value, type"
    forward_named add, "lhs, rhs"
    forward_named sub, "lhs, rhs"
    forward_named mul, "lhs, rhs"
    forward_named sdiv, "lhs, rhs"
    forward_named udiv, "lhs, rhs"
    forward_named srem, "lhs, rhs"
    forward_named urem, "lhs, rhs"
    forward_named shl, "lhs, rhs"
    forward_named ashr, "lhs, rhs"
    forward_named lshr, "lhs, rhs"
    forward_named or, "lhs, rhs"
    forward_named and, "lhs, rhs"
    forward_named xor, "lhs, rhs"
    forward_named fadd, "lhs, rhs"
    forward_named fsub, "lhs, rhs"
    forward_named fmul, "lhs, rhs"
    forward_named fdiv, "lhs, rhs"
    forward_named icmp, "op, lhs, rhs"
    forward_named fcmp, "op, lhs, rhs"
    forward_named not, "value"
    forward_named select, "a_cond, a_then, a_else"
    forward_named global_string_pointer, "string"
  end
end

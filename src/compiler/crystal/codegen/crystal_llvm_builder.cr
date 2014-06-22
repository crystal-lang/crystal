module Crystal
  class CrystalLLVMBuilder
    getter :end

    def initialize(@builder, @codegen)
      @end = false
    end

    def llvm_nil
      @codegen.llvm_nil
    end

    def ret
      return llvm_nil if @end
      value = @builder.ret
      @end = true
      value
    end

    def ret(value)
      return llvm_nil if @end
      value = @builder.ret(value)
      @end = true
      value
    end

    def br(block)
      return llvm_nil if @end
      value = @builder.br(block)
      @end = true
      value
    end

    def unreachable
      if ENV["UNREACHABLE"] == "1"
        @codegen.printf("Reached the unreachable!")
      end
      return if @end
      value = @builder.unreachable
      @end = true
      value
    end

    def position_at_end(block)
      @builder.position_at_end block
      @end = false
    end

    macro forward(name)
      def {{name.id}}
        return llvm_nil if @end
        @builder.{{name.id}}
      end
    end

    macro forward(name, args)
      def {{name.id}}({{args.id}})
        return llvm_nil if @end
        @builder.{{name.id}}({{args.id}})
      end
    end

    macro forward(name, def_args, call_args)
      def {{name.id}}({{def_args.id}})
        return llvm_nil if @end
        @builder.{{name.id}}({{call_args.id}})
      end
    end

    macro forward_named(name, args)
      def {{name.id}}({{args.id}}, name = "")
        return llvm_nil if @end
        @builder.{{name.id}}({{args.id}}, name)
      end
    end

    def insert_block
      @builder.insert_block
    end

    forward cond, "cond, then_block, else_block"
    forward phi, "type, table : LLVM::PhiTable, name = \"\"", "type, table, name"
    forward phi, "type, incoming_blocks, incoming_values, name = \"\"", "type, incoming_blocks, incoming_values, name"
    forward call, "func, args = [] of LibLLVM::ValueRef", "func, args"
    forward_named alloca, "type"
    forward store, "value, ptr"
    forward_named load, "ptr"
    forward_named malloc, "type"
    forward_named array_malloc, "type, value"
    forward_named gep, "value, indices"
    forward_named inbounds_gep, "value, indices"
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
    forward_named exact_sdiv, "lhs, rhs"
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
    forward_named landing_pad, "type, personality, clauses"
    forward_named invoke, "fn, args, a_then, a_catch"
  end
end

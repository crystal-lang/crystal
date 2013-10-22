require "parser"
require "type_inference"
require "visitor"
require "llvm"
require "codegen/*"
require "program"

LLVM.init_x86

module Crystal
  DUMP_LLVM = ENV["DUMP"] == "1"
  MAIN_NAME = "__crystal_main"

  class Program
    def run(code)
      node = Parser.parse(code)
      node = infer_type node
      evaluate node
    end

    def evaluate(node)
      llvm_mod = build node
      engine = LLVM::JITCompiler.new(llvm_mod)

      argc = LibLLVM.create_generic_value_of_int(LLVM::Int32, 0_u64, 1)
      argv = LibLLVM.create_generic_value_of_pointer(nil)

      engine.run_function llvm_mod.functions[MAIN_NAME], [argc, argv]
    end

    def build(node)
      visitor = CodeGenVisitor.new(self, node)
      begin
        node.accept visitor
        visitor.finish
      rescue ex
        visitor.llvm_mod.dump
        raise ex
      end
      visitor.llvm_mod.dump if Crystal::DUMP_LLVM
      visitor.llvm_mod

    end
  end

  class LLVMVar
    getter pointer
    getter type

    def initialize(@pointer, @type)
    end
  end

  class CodeGenVisitor < Visitor
    getter :llvm_mod
    getter :fun
    getter :builder
    getter :typer
    getter :main
    getter! :type

    def initialize(@mod, @node)
      @llvm_mod = LLVM::Module.new("Crystal")
      @llvm_typer = LLVMTyper.new
      @main_ret_type = node.type
      ret_type = @llvm_typer.llvm_type(node.type)
      @fun = @llvm_mod.functions.add(MAIN_NAME, [LLVM::Int32, LLVM.pointer_type(LLVM.pointer_type(LLVM::Int8))], ret_type)
      @main = @fun

      @argc = @fun.get_param(0)
      # @argc.name = 'argc'

      @argv = @fun.get_param(1)
      # @argv.name = 'argv'

      @builder = LLVM::Builder.new
      @alloca_block, @const_block, @entry_block = new_entry_block_chain ["alloca", "const", "entry"]
      @const_block_entry = @const_block
      @vars = {} of String => LLVMVar
      @strings = {} of String => LibLLVM::ValueRef
      @type = @mod
      @last = llvm_nil
      @in_const_block = false
      # @return_union = llvm_nil
    end

    def finish
      br_block_chain [@alloca_block, @const_block_entry]
      br_block_chain [@const_block, @entry_block]

      return_from_fun nil, @main_ret_type
    end

    def visit(node : FunDef)
      unless node.external.dead
        codegen_fun node.real_name, node.external, nil, true
      end

      false
    end

    # Can only happen in a Const
    def visit(node : Primitive)
      @last = case node.name
              when :argc
                @argc
              when :argv
                @argv
              when :float32_infinity
                LLVM.float(Float32::INFINITY)
              when :float64_infinity
                LLVM.double(Float64::INFINITY)
              else
                raise "Bug: unhandled primitive in codegen: #{node.name}"
              end
    end

    def codegen_primitive(node, target_def, call_args)
      @last = case node.name
              when :binary
                codegen_primitive_binary node, target_def, call_args
              when :cast
                codegen_primitive_cast node, target_def, call_args
              when :allocate
                codegen_primitive_allocate node, target_def, call_args
              when :pointer_malloc
                codegen_primitive_pointer_malloc node, target_def, call_args
              when :pointer_set
                codegen_primitive_pointer_set node, target_def, call_args
              when :pointer_get
                codegen_primitive_pointer_get node, target_def, call_args
              when :pointer_address
                codegen_primitive_pointer_address node, target_def, call_args
              when :pointer_new
                codegen_primitive_pointer_new node, target_def, call_args
              when :pointer_realloc
                codegen_primitive_pointer_realloc node, target_def, call_args
              when :pointer_cast
                codegen_primitive_pointer_cast node, target_def, call_args
              when :byte_size
                codegen_primitive_byte_size node, target_def, call_args
              when :struct_new
                codegen_primitive_struct_new node, target_def, call_args
              when :struct_set
                codegen_primitive_struct_set node, target_def, call_args
              when :struct_get
                codegen_primitive_struct_get node, target_def, call_args
              when :union_new
                codegen_primitive_union_new node, target_def, call_args
              when :union_set
                codegen_primitive_union_set node, target_def, call_args
              when :union_get
                codegen_primitive_union_get node, target_def, call_args
              else
                raise "Bug: unhandled primitive in codegen: #{node.name}"
              end
    end

    def codegen_primitive_binary(node, target_def, call_args)
      p1, p2 = call_args
      t1, t2 = target_def.owner, target_def.args[0].type
      codegen_binary_op target_def.name, t1, t2, p1, p2
    end

    def codegen_binary_op(op, t1 : BoolType, t2 : BoolType, p1, p2)
      case op
      when "==" then @builder.icmp LibLLVM::IntPredicate::EQ, p1, p2
      when "!=" then @builder.icmp LibLLVM::IntPredicate::NE, p1, p2
      else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
      end
    end

    def codegen_binary_op(op, t1 : IntegerType, t2 : IntegerType, p1, p2)
      if t1.normal_rank == t2.normal_rank
        # Nothing to do
      elsif t1.rank < t2.rank
        p1 = t1.signed? ? @builder.sext(p1, t2.llvm_type) : @builder.zext(p1, t2.llvm_type)
      else
        p2 = t2.signed? ? @builder.sext(p2, t1.llvm_type) : @builder.zext(p2, t1.llvm_type)
      end

      @last = case op
              when "+" then @builder.add p1, p2
              when "-" then @builder.sub p1, p2
              when "*" then @builder.mul p1, p2
              when "/" then t1.signed? ? @builder.sdiv(p1, p2) : @builder.udiv(p1, p2)
              when "%" then t1.signed? ? @builder.srem(p1, p2) : @builder.urem(p1, p2)
              when "<<" then @builder.shl(p1, p2)
              when ">>" then t1.signed? ? @builder.ashr(p1, p2) : @builder.lshr(p1, p2)
              when "|" then @builder.or(p1, p2)
              when "&" then @builder.and(p1, p2)
              when "^" then @builder.xor(p1, p2)
              when "==" then return @builder.icmp LibLLVM::IntPredicate::EQ, p1, p2
              when "!=" then return @builder.icmp LibLLVM::IntPredicate::NE, p1, p2
              when "<" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SLT : LibLLVM::IntPredicate::ULT), p1, p2
              when "<=" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SLE : LibLLVM::IntPredicate::ULE), p1, p2
              when ">" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SGT : LibLLVM::IntPredicate::UGT), p1, p2
              when ">=" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SGT : LibLLVM::IntPredicate::UGT), p1, p2
              else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
              end

      if t1.normal_rank != t2.normal_rank  && t1.rank < t2.rank
        @last = @builder.trunc @last, t1.llvm_type
      end

      @last
    end

    def codegen_binary_op(op, t1 : IntegerType, t2 : FloatType, p1, p2)
      p1 = if t1.signed?
            @builder.si2fp(p1, t2.llvm_type)
           else
             @builder.ui2fp(p1, t2.llvm_type)
           end
      codegen_binary_op(op, t2, t2, p1, p2)
    end

    def codegen_binary_op(op, t1 : FloatType, t2 : IntegerType, p1, p2)
      p2 = if t2.signed?
            @builder.si2fp(p2, t1.llvm_type)
           else
             @builder.ui2fp(p2, t1.llvm_type)
           end
      codegen_binary_op op, t1, t1, p1, p2
    end

    def codegen_binary_op(op, t1 : FloatType, t2 : FloatType, p1, p2)
      if t1.rank < t2.rank
        p1 = @builder.fpext(p1, t2.llvm_type)
      elsif t1.rank > t2.rank
        p2 = @builder.fpext(p2, t1.llvm_type)
      end

      @last = case op
              when "+" then @builder.fadd p1, p2
              when "-" then @builder.fsub p1, p2
              when "*" then @builder.fmul p1, p2
              when "/" then @builder.fdiv p1, p2
              when "==" then return @builder.fcmp LibLLVM::RealPredicate::OEQ, p1, p2
              when "!=" then return @builder.fcmp LibLLVM::RealPredicate::ONE, p1, p2
              when "<" then return @builder.fcmp LibLLVM::RealPredicate::OLT, p1, p2
              when "<=" then return @builder.fcmp LibLLVM::RealPredicate::OLE, p1, p2
              when ">" then return @builder.fcmp LibLLVM::RealPredicate::OGT, p1, p2
              when ">=" then return @builder.fcmp LibLLVM::RealPredicate::OGE, p1, p2
              else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
              end

      if t1.rank < t2.rank
        @last = @builder.fptrunc(@last, t1.llvm_type)
      end

      @last
    end

    def codegen_binary_op(op, t1, t2, p1, p2)
      raise "Bug: codegen_binary_op called with #{t1} #{op} #{t2}"
    end

    def codegen_primitive_cast(node, target_def, call_args)
      p1 = call_args[0]
      from_type, to_type = target_def.owner, target_def.type
      codegen_cast from_type, to_type, p1
    end

    def codegen_cast(from_type : IntegerType, to_type : IntegerType, arg)
      if from_type.normal_rank == to_type.normal_rank
        @last
      elsif from_type.rank < to_type.rank
        from_type.signed? ? @builder.sext(arg, to_type.llvm_type) : @builder.zext(arg, to_type.llvm_type)
      else
        @builder.trunc(arg, to_type.llvm_type)
      end
    end

    def codegen_cast(from_type : IntegerType, to_type : FloatType, arg)
      if from_type.signed?
        @builder.si2fp(arg, to_type.llvm_type)
      else
        @builder.ui2fp(arg, to_type.llvm_type)
      end
    end

    def codegen_cast(from_type : FloatType, to_type : IntegerType, arg)
      if to_type.signed?
        @builder.fp2si(arg, to_type.llvm_type)
      else
        @builder.fp2ui(arg, to_type.llvm_type)
      end
    end

    def codegen_cast(from_type : FloatType, to_type : FloatType, arg)
      if from_type.rank < to_type.rank
        @last = @builder.fpext(arg, to_type.llvm_type)
      elsif from_type.rank > to_type.rank
        @last = @builder.fptrunc(arg, to_type.llvm_type)
      end
      @last
    end

    def codegen_cast(from_type : IntegerType, to_type : CharType, arg)
      codegen_cast(from_type, @mod.int8, arg)
    end

    def codegen_cast(from_type : CharType, to_type : IntegerType, arg)
      @builder.zext(arg, to_type.llvm_type)
    end

    def codegen_cast(from_type, to_type, arg)
      raise "Bug: codegen_cast called from #{from_type} to #{to_type}"
    end

    def codegen_primitive_allocate(node, target_def, call_args)
      malloc llvm_struct_type(node.type)
    end

    def codegen_primitive_pointer_malloc(node, target_def, call_args)
      type = node.type
      assert_type type, PointerInstanceType

      llvm_type = llvm_embedded_type(type.var.type)
      @builder.array_malloc(llvm_type, call_args[1])
    end

    def codegen_primitive_pointer_set(node, target_def, call_args)
      value = call_args[1]

      type = @type
      assert_type type, PointerInstanceType

      # if node.type.c_struct? || node.type.c_union?
      #   loaded_value = @builder.load value
      #   @builder.store loaded_value, @fun.params[0]
      #   @last = value
      #   return
      # end

      # if node.type.union?
      #   value = @builder.alloca llvm_type(node.type)
      #   target = @fun.params[1]
      #   target = @builder.load(target) if node.type.passed_by_val?
      #   @builder.store target, value
      # end

      codegen_assign call_args[0], type.var.type, node.type, value

      value
    end

    def codegen_primitive_pointer_get(node, target_def, call_args)
      # if @type.var.type.union? || @type.var.type.c_struct? || @type.var.type.c_union?
      #   @last = llvm_self
      # else
        @builder.load call_args[0]
      # end
    end

    def codegen_primitive_pointer_address(node, target_def, call_args)
      @builder.ptr2int call_args[0], LLVM::Int64
    end

    def codegen_primitive_pointer_new(node, target_def, call_args)
      @builder.int2ptr(call_args[1], llvm_type(node.type))
    end

    def codegen_primitive_pointer_realloc(node, target_def, call_args)
      type = @type
      assert_type type, PointerInstanceType

      casted_ptr = cast_to_void_pointer(call_args[0])
      size = call_args[1]
      size = @builder.mul size, llvm_size(type.var.type)
      reallocated_ptr = realloc casted_ptr, size
      @last = cast_to_pointer reallocated_ptr, type.var.type
    end

    def codegen_primitive_pointer_cast(node, target_def, call_args)
      @last = cast_to call_args[0], node.type
    end

    def codegen_primitive_byte_size(node, target_def, call_args)
      llvm_size(type.instance_type)
    end

    def codegen_primitive_struct_new(node, target_def, call_args)
      struct_type = llvm_struct_type(node.type)
      @last = malloc struct_type
      memset @last, int8(0), LLVM.size_of(struct_type)
      @last
    end

    def codegen_primitive_struct_set(node, target_def, call_args)
      type = @type
      assert_type type, CStructType

      name = target_def.name[0 .. -2]

      ptr = gep call_args[0], 0, type.index_of_var(name)
      @last = call_args[1]
      value = @last
      value = @builder.load @last if node.type.c_struct? || node.type.c_union?
      @builder.store value, ptr
      call_args[1]
    end

    def codegen_primitive_struct_get(node, target_def, call_args)
      type = @type
      assert_type type, CStructType

      name = target_def.name

      var = type.vars[name]
      index = type.index_of_var(name)
      if var.type.c_struct? || var.type.c_union?
        gep call_args[0], 0, index
      else
        struct = @builder.load call_args[0]
        @builder.extract_value struct, index, name
      end
    end

    def codegen_primitive_union_new(node, target_def, call_args)
      struct_type = llvm_struct_type(node.type)
      @last = malloc struct_type
      memset @last, int8(0), LLVM.size_of(struct_type)
      @last
    end

    def codegen_primitive_union_set(node, target_def, call_args)
      type = @type
      assert_type type, CUnionType

      name = target_def.name[0 .. -2]

      var = type.vars[name]
      ptr = gep call_args[0], 0, 0
      casted_value = cast_to_pointer ptr, var.type
      @last = call_args[1]
      @builder.store @last, casted_value
      @last
    end

    def codegen_primitive_union_get(node, target_def, call_args)
      type = @type
      assert_type type, CUnionType

      name = target_def.name

      var = type.vars[name]
      ptr = gep call_args[0], 0, 0
      if var.type.c_struct? || var.type.c_union?
        @last = @builder.bit_cast(ptr, LLVM.pointer_type(llvm_struct_type(var.type)))
      else
        casted_value = cast_to_pointer ptr, var.type
        @last = @builder.load casted_value
      end
    end

    def visit(node : PointerOf)
      node_var = node.var
      case node_var
      when Var
        var = @vars[node_var.name]
        @last = var.pointer
        # @last = @builder.load @last if node.type.var.type.c_struct? || node.type.var.type.c_union?
      when InstanceVar
        type = @type
        assert_type type, InstanceVarContainer

        @last = gep llvm_self_ptr, 0, type.index_of_instance_var(node_var.name)
      else
        raise "Bug: #{node}.ptr"
      end
      false
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : NumberLiteral)
      case node.kind
      when :i8, :u8
        @last = int8(node.value.to_i)
      when :i16, :u16
        @last = int16(node.value.to_i)
      when :i32, :u32
        @last = int32(node.value.to_i)
      when :i64, :u64
        @last = int64(node.value.to_i64)
      when :f32
        @last = LLVM.float(node.value)
      when :f64
        @last = LLVM.double(node.value)
      end
    end

    def visit(node : BoolLiteral)
      @last = int1(node.value ? 1 : 0)
    end

    def visit(node : LongLiteral)
      @last = int64(node.value.to_i)
    end

    def visit(node : CharLiteral)
      @last = int8(node.value[0].ord)
    end

    def visit(node : StringLiteral)
      @last = build_string_constant(node.value)
    end

    def visit(node : Nop)
      @last = llvm_nil
    end

    def visit(node : NilLiteral)
      @last = llvm_nil
    end

    def visit(node : ClassDef)
      node.body.accept self
      @last = llvm_nil
      false
    end

    def visit(node : ModuleDef)
      node.body.accept self
      @last = llvm_nil
      false
    end

    def visit(node : LibDef)
      @last = llvm_nil
      false
    end

    def visit(node : Include)
      @last = llvm_nil
      false
    end

    def build_string_constant(str, name = "str")
      # name = name.gsub('@', '.')
      @strings[str] ||= begin
        global = @llvm_mod.globals.add(LLVM.array_type(LLVM::Int8, str.length + 5), name)
        LLVM.set_linkage global, LibLLVM::Linkage::Private
        LLVM.set_global_constant global, true

        # Pack the string bytes
        bytes = [] of LibLLVM::ValueRef
        length = str.length
        length_ptr = length.ptr.as(UInt8)
        (0..3).each { |i| bytes << int8(length_ptr[i]) }
        str.each_char { |c| bytes << int8(c.ord) }
        bytes << int8(0)

        LLVM.set_initializer global, LLVM.array(LLVM::Int8, bytes)
        cast_to global, @mod.string
      end
    end

    def cast_to(value, type)
      @builder.bit_cast(value, llvm_type(type))
    end

    def cast_to_pointer(value, type)
      @builder.bit_cast(value, LLVM.pointer_type(llvm_type(type)))
    end

    def cast_to_void_pointer(pointer)
      @builder.bit_cast pointer, LLVM.pointer_type(LLVM::Int8)
    end

    def visit(node : If)
      accept(node.cond)

      then_block, else_block = new_blocks ["then", "else"]
      codegen_cond_branch(node.cond, then_block, else_block)

      branch = new_branched_block(node)

      @builder.position_at_end then_block
      accept(node.then)
      add_branched_block_value(branch, node.then.type, @last)

      @builder.position_at_end else_block
      accept(node.else)
      add_branched_block_value(branch, node.else.type, @last)

      close_branched_block(branch)

      false
    end

    def visit(node : While)
      # old_break_type = @break_type
      # old_break_table = @break_table
      # old_break_union = @break_union
      # @break_type = @break_table = @break_union = nil

      while_block, body_block, exit_block = new_blocks ["while", "body", "exit"]

      @builder.br node.run_once ? body_block : while_block

      @builder.position_at_end while_block

      accept(node.cond)
      codegen_cond_branch(node.cond, body_block, exit_block)

      @builder.position_at_end body_block
      old_while_exit_block = @while_exit_block
      @while_exit_block = exit_block
      accept(node.body)
      @while_exit_block = old_while_exit_block
      @builder.br while_block

      @builder.position_at_end exit_block
      # @builder.unreachable if node.no_returns? || (node.body.yields? && block_breaks?)

      @last = llvm_nil
      # @break_type = old_break_type
      # @break_table = old_break_table
      # @break_union = old_break_union

      false
    end

    def codegen_cond_branch(node_cond, then_block, else_block)
      @builder.cond(codegen_cond(node_cond.type), then_block, else_block)

      nil
    end


    def codegen_cond(type : NilType)
      int1(0)
    end

    def codegen_cond(type : BoolType)
      @last
      # elsif node_cond.type.nilable?
      #   cond = not_null_pointer?(@last)
      # elsif node_cond.type.hierarchy?
      #   cond = int1(1)
      # elsif node_cond.type.union?
      #   has_nil = node_cond.type.types.any?(&:nil_type?)
      #   has_bool = node_cond.type.types.any? { |t| t.equal?(@mod.bool) }

      #   if has_nil || has_bool
      #     type_id = @builder.load union_type_id(@last)
      #     value = @builder.load(@builder.bit_cast union_value(@last), LLVM::Pointer(LLVM::Int1))

      #     is_nil = @builder.icmp :eq, type_id, int(@mod.nil.type_id)
      #     is_bool = @builder.icmp :eq, type_id, int(@mod.bool.type_id)
      #     is_false = @builder.icmp(:eq, value, int1(0))
      #     cond = @builder.not(@builder.or(is_nil, @builder.and(is_bool, is_false)))
      #   elsif has_nil
      #     type_id = @builder.load union_type_id(@last)
      #     cond = @builder.icmp :ne, type_id, int(@mod.nil.type_id)
      #   elsif has_bool
      #     type_id = @builder.load union_type_id(@last)
      #     value = @builder.load(@builder.bit_cast union_value(@last), LLVM::Pointer(LLVM::Int1))

      #     is_bool = @builder.icmp :eq, type_id, int(@mod.bool.type_id)
      #     is_false = @builder.icmp(:eq, value, int1(0))
      #     cond = @builder.not(@builder.and(is_bool, is_false))
      #   else
      #     cond = int1(1)
      #   end
      # elsif node_cond.type.is_a?(PointerInstanceType)
      #   cond = not_null_pointer?(@last)
      # end
    end

    def codegen_cond(node_cond)
      int1(1)
    end

    abstract class BranchedBlock
      property node
      property count
      property exit_block

      def initialize(@node, @exit_block, @codegen)
        @count = 0
      end
    end

    class UnionBranchedBlock < BranchedBlock
      def initialize(node, exit_block, codegen)
        super
        @union_ptr = @codegen.alloca(@codegen.llvm_type(node.type))
      end

      def add_value(block, type, value)
        @codegen.assign_to_union(@union_ptr, @node.type, type, value)
        @count += 1
      end

      def close
        @union_ptr
      end
    end

    class PhiBranchedBlock < BranchedBlock
      def initialize(node, exit_block, codegen)
        super
        @incoming_blocks = [] of LibLLVM::BasicBlockRef
        @incoming_values = [] of LibLLVM::ValueRef
      end

      def add_value(block, type, value)
        # if branch[:node].type.nilable? && value.type.kind == :integer
        #   branch[:phi_table][@builder.insert_block] = @builder.int2ptr value, llvm_type(branch[:node].type)
        # else
        #   branch[:phi_table][@builder.insert_block] = value
        # end
        @incoming_blocks << block
        @incoming_values << value
        @count += 1
      end

      def close
        # if branch[:count] == 0
        #   @builder.unreachable
        # elsif branch[:phi_table].empty?
        #   # All branches are void or no return
        #   @last = llvm_nil
        # else
        @codegen.builder.phi @codegen.llvm_type(@node.type), @incoming_blocks, @incoming_values
      end
    end

    def new_branched_block(node)
      exit_block = new_block("exit")
      node_type = node.type
      if node_type && node_type.union?
        UnionBranchedBlock.new node, exit_block, self
      else
        PhiBranchedBlock.new node, exit_block, self
      end
    end

    def add_branched_block_value(branch, type, value : LibLLVM::ValueRef)
      if false # !type || type.no_return?
        # @builder.unreachable
      elsif false # type.equal?(@mod.void)
        # Nothing to do
        branch.count += 1
      else
        branch.add_value @builder.insert_block, type, value
        @builder.br branch.exit_block
      end
    end

    def close_branched_block(branch)
      @builder.position_at_end branch.exit_block
      if false # branch.node.returns? || branch.node.no_returns?
        # @builder.unreachable
      else
        @last = branch.close
      end
    end

    def visit(node : Assign)
      codegen_assign_node(node.target, node.value)
    end

    def codegen_assign_node(target, value)
      if target.is_a?(Ident)
        @last = llvm_nil
        return false
      end

      # if target.is_a?(ClassVar) && target.class_scope
      #   global_name = class_var_global_name(target)
      #   in_const_block(global_name) do
      #     accept(value)
      #     llvm_value = @last
      #     ptr = assign_to_global global_name, target.type
      #     codegen_assign(ptr, target.type, value.type, llvm_value)
      #   end
      #   return
      # end

      accept(value)

      # if value.no_returns?
      #   return
      # end

      codegen_assign_target(target, value, @last) if @last

      false
    end

    def codegen_assign_target(target : InstanceVar, value, llvm_value)
      type = @type
      assert_type type, InstanceVarContainer

      ivar = type.lookup_instance_var(target.name)
      index = type.index_of_instance_var(target.name)

      ptr = gep llvm_self_ptr, 0, index
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target : Global, value, llvm_value)
      ptr = get_global target.name, target.type
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target : ClassVar, value, llvm_value)
      ptr = get_global class_var_global_name(target), target.type
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target : Var, value, llvm_value)
      var = declare_var(target)
      ptr = var.pointer
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target, value, llvm_value)
      raise "Unknown assign target in codegen: #{target}"
    end

    def get_global(name, type)
      ptr = @llvm_mod.globals[name]?
      unless ptr
        llvm_type = llvm_type(type)
        ptr = @llvm_mod.globals.add(llvm_type, name)
        LLVM.set_linkage ptr, LibLLVM::Linkage::Internal
        LLVM.set_initializer ptr, LLVM.null(llvm_type)
      end
      ptr
    end

    def class_var_global_name(node)
      "#{node.owner}#{node.var.name.replace('@', ':')}"
    end

    def codegen_assign(pointer, target_type, value_type, value, instance_var = false)
      if target_type == value_type
        value = @builder.load value if target_type.union? #|| (instance_var && (target_type.c_struct? || target_type.c_union?))
        @builder.store value, pointer
      else
        assign_to_union(pointer, target_type, value_type, value)
      end
      nil
    end

    def assign_to_union(union_pointer, union_type, type, value)
      # if union_type.nilable?
      #   if value.type.kind == :integer
      #     value = @builder.int2ptr value, llvm_type(union_type.nilable_type)
      #   end
      #   @builder.store value, union_pointer
      #   return
      # end

      type_id_ptr, value_ptr = union_type_id_and_value(union_pointer)

      # if type.union?
      #   casted_value = cast_to_pointer value, union_type
      #   @builder.store @builder.load(casted_value), union_pointer
      # elsif type.nilable?
      #   index = @builder.select null_pointer?(value), int(@mod.nil.type_id), int(type.nilable_type.type_id)

      #   @builder.store index, type_id_ptr

      #   casted_value_ptr = cast_to_pointer value_ptr, type.nilable_type
      #   @builder.store value, casted_value_ptr
      # else
        index = type.type_id
        @builder.store int32(index), type_id_ptr

        casted_value_ptr = cast_to_pointer value_ptr, type
        @builder.store value, casted_value_ptr
      # end
    end

    def union_type_id_and_value(union_pointer)
      type_id_ptr = union_type_id(union_pointer)
      value_ptr = union_value(union_pointer)
      [type_id_ptr, value_ptr]
    end

    def union_type_id(union_pointer)
      gep union_pointer, 0, 0
    end

    def union_value(union_pointer)
      gep union_pointer, 0, 1
    end

    def visit(node : Var)
      var = @vars[node.name]
      @last = @builder.load(var.pointer)
      # if var[:type] == node.type
      #   @last = var[:ptr]
      #   @last = @builder.load(@last, node.name) unless (var[:treated_as_pointer] || var[:type].union?)
      # elsif var[:type].nilable?
      #   if node.type.nil_type?
      #     @last = null_pointer?(var[:ptr])
      #   else
      #     @last = var[:ptr]
      #     @last = @builder.load(@last, node.name) unless (var[:treated_as_pointer] || var[:type].union?)
      #   end
      # else
      #   if node.type.union?
      #     @last = cast_to_pointer var[:ptr], node.type
      #   else
      #     value_ptr = union_value(var[:ptr])
      #     @last = cast_to_pointer value_ptr, node.type
      #     @last = @builder.load(@last) unless node.type.passed_by_val?
      #   end
      # end
    end

    def visit(node : Global)
      read_global node.name.to_s, node.type
    end

    def visit(node : ClassVar)
      read_global class_var_global_name(node), node.type
    end

    def read_global(name, type)
      @last = get_global name, type
      @last = @builder.load @last unless type.union?
      @last
    end

    def visit(node : InstanceVar)
      type = @type
      assert_type type, InstanceVarContainer

      ivar = type.lookup_instance_var(node.name)
      # if ivar.type.union? || ivar.type.c_struct? || ivar.type.c_union?
      #   @last = gep llvm_self_ptr, 0, @type.index_of_instance_var(node.name)
      #   unless node.type.equal?(ivar.type)
      #     if node.type.union?
      #       @last = cast_to_pointer @last, node.type
      #     else
      #       value_ptr = union_value(@last)
      #       @last = cast_to_pointer value_ptr, node.type
      #       @last = @builder.load(@last)
      #     end
      #   end
      # else
        index = type.index_of_instance_var(node.name)

        struct = @builder.load llvm_self_ptr
        @last = @builder.extract_value struct, index, node.name
      # end
    end


    def declare_var(var)
      @vars[var.name] ||= begin
        llvm_var = LLVMVar.new(alloca(llvm_type(var.type), var.name), var.type)
        # if var.type.is_a?(UnionType) && union_type_id = var.type.types.any?(&:nil_type?)
        #   in_alloca_block { assign_to_union(llvm_var[:ptr], var.type, @mod.nil, llvm_nil) }
        # end
        llvm_var
      end
    end

    def visit(node : Def)
      false
    end

    def visit(node : Macro)
      false
    end

    def visit(node : Ident)
      const = node.target_const
      if const
        global_name = const.llvm_name
        global = @llvm_mod.globals[global_name]?

        unless global
          global = @llvm_mod.globals.add(llvm_type(const.value.type), global_name)
          LLVM.set_linkage global, LibLLVM::Linkage::Internal

          if const.value.needs_const_block?
            in_const_block("const_#{global_name}") do
              accept(const.value)

              if LLVM.constant? @last
                LLVM.set_initializer global, @last
                LLVM.set_global_constant global, true
              else
                LLVM.set_initializer global, LLVM.null(LLVM.type_of @last)
                @builder.store @last, global
              end
            end
          else
            accept(const.value)
            LLVM.set_initializer global, @last
            LLVM.set_global_constant global, true
          end
        end

        @last = @builder.load global
      else
        @last = int64(node.type.instance_type.type_id)
      end
      false
    end

    def visit(node : Call)
      owner = node.target_def.owner

      call_args = [] of LibLLVM::ValueRef

      if (obj = node.obj) && obj.type.passed_as_self?
        accept(obj)
        call_args << @last
      elsif owner && owner.passed_as_self?
        call_args << llvm_self
      end

      node.args.each_with_index do |arg, i|
        accept(arg)
        call_args << @last
      end

      codegen_call(node, owner, call_args)

      false
    end

    def codegen_call(node, self_type, call_args)
      target_def = node.target_def
      body = target_def.body
      if body.is_a?(Primitive)
        old_type = @type
        @type = self_type
        codegen_primitive(body, target_def, call_args)
        @type = old_type
        return
      end

      mangled_name = target_def.mangled_name(self_type)

      func = @llvm_mod.functions[mangled_name]? || codegen_fun(mangled_name, target_def, self_type)

      @last = @builder.call func, call_args

      if target_def.type.union?
        union = alloca llvm_type(target_def.type)
        @builder.store @last, union
        @last = union
      end
    end

    def codegen_fun(mangled_name, target_def, self_type, is_exported_fun_def = false)
      # if target_def.type.same?(@mod.void)
      #   llvm_return_type = LLVM.Void
      # else
        llvm_return_type = llvm_type(target_def.type)
      # end

      old_position = @builder.insert_block
      old_fun = @fun
      old_vars = @vars
      old_entry_block = @entry_block
      old_alloca_block = @alloca_block
      old_type = @type
      old_target_def = @target_def

      @vars = {} of String => LLVMVar

      args = [] of Arg
      if self_type && self_type.passed_as_self?
        @type = self_type
        args << Arg.new_with_type("self", self_type)
      end
      args.concat target_def.args

      if target_def.is_a?(External)
        is_external = true
        varargs = target_def.varargs
      end

      @fun = @llvm_mod.functions.add(
        mangled_name,
        args.map { |arg| llvm_arg_type(arg.type) },
        llvm_return_type,
        varargs
      )

      unless is_external
        @fun.linkage = LibLLVM::Linkage::Internal
      end

      # args.each_with_index do |arg, i|
      #   @fun.params[i].name = arg.name
      #   # @fun.params[i].add_attribute :by_val_attribute if arg.type.passed_by_val?
      # end

      if (!is_external && target_def.body) || is_exported_fun_def
        body = target_def.body
        new_entry_block

        args.each_with_index do |arg, i|
          if target_def.body.is_a?(Primitive)
          # if (self_type && i == 0 && !self_type.union?) || target_def.body.is_a?(Primitive) || arg.type.passed_by_val?
            @vars[arg.name] = LLVMVar.new(@fun.get_param(i), arg.type) #{ ptr: @fun.params[i], type: arg.type, treated_as_pointer: true }
          else
            pointer = alloca(llvm_type(arg.type), arg.name)
            @vars[arg.name] = LLVMVar.new(pointer, arg.type)
            @builder.store @fun.get_param(i), pointer
          end
        end

        if body
          old_return_type = @return_type
          # old_return_union = @return_union
          @return_type = target_def.type
          return_type = @return_type
          # @return_union = alloca(llvm_type(return_type), "return") if return_type.union?

          accept body

          return_from_fun target_def, return_type

          @return_type = old_return_type
          # @return_union = old_return_union
        end

        br_from_alloca_to_entry

        @builder.position_at_end old_position
      end

      @last = llvm_nil

      the_fun = @fun

      @vars = old_vars
      @fun = old_fun
      @entry_block = old_entry_block
      @alloca_block = old_alloca_block
      @type = old_type

      the_fun
    end

    def return_from_fun(target_def, return_type)
      # if target_def.type == @mod.void
      #   ret nil
      # elsif target_def.body.no_returns?
      #   @builder.unreachable
      # else
        if return_type.union?
          # if target_def.body.type != @return_type && !target_def.body.returns?
          #   assign_to_union(@return_union, @return_type, target_def.body.type, @last)
          #   @last = @builder.load @return_union
          # else
            @last = @builder.load @last
          # end
        end

        # if @return_type.nilable? && target_def.body.type && target_def.body.type.nil_type?
        #   ret LLVM::Constant.null(llvm_type(@return_type))
        # else
          ret(@last)
        # end
      # end
    end

    def new_entry_block
      @alloca_block, @entry_block = new_entry_block_chain ["alloca", "entry"]
    end

    def new_entry_block_chain names
      blocks = new_blocks names
      @builder.position_at_end blocks.last
      blocks
    end

    def br_from_alloca_to_entry
      br_block_chain [@alloca_block, @entry_block]
    end

    def br_block_chain blocks
      old_block = @builder.insert_block

      0.upto(blocks.count - 2) do |i|
        @builder.position_at_end blocks[i]
        @builder.br blocks[i + 1]
      end

      @builder.position_at_end old_block
    end

    def new_block(name)
      @fun.append_basic_block(name)
    end

    def new_blocks(names)
      names.map { |name| new_block name }
    end

    def alloca(type, name = "")
      in_alloca_block { @builder.alloca type, name }
    end

    def in_alloca_block
      old_block = @builder.insert_block
      @builder.position_at_end @alloca_block
      value = yield
      @builder.position_at_end old_block
      value
    end

    def in_const_block(const_block_name)
      old_position = @builder.insert_block
      old_fun = @fun
      old_in_const_block = @in_const_block
      @in_const_block = true

      @fun = @main
      const_block = new_block const_block_name
      @builder.position_at_end const_block

      yield

      new_const_block = @builder.insert_block
      @builder.position_at_end @const_block
      @builder.br const_block
      @const_block = new_const_block

      @builder.position_at_end old_position
      @fun = old_fun
      @in_const_block = old_in_const_block
    end

    def gep(ptr, index0, index1)
      @builder.gep ptr, [int32(index0), int32(index1)]
    end

    def malloc(type)
      @builder.malloc type
    end

    def memset(pointer, value, size)
      pointer = cast_to_void_pointer pointer
      @builder.call @mod.memset(@llvm_mod), [pointer, value, @builder.trunc(size, LLVM::Int32), int32(4), int1(0)]
    end

    def realloc(buffer, size)
      @builder.call @mod.realloc(@llvm_mod), [buffer, size]
    end

    def llvm_type(type)
      @llvm_typer.llvm_type(type)
    end

    def llvm_struct_type(type)
      @llvm_typer.llvm_struct_type(type)
    end

    def llvm_arg_type(type)
      @llvm_typer.llvm_arg_type(type)
    end

    def llvm_embedded_type(type)
      @llvm_typer.llvm_embedded_type(type)
    end

    def llvm_size(type)
      LLVM.size_of llvm_type(type)
    end

    def llvm_self
      @fun.get_param(0)
      # @vars["self"].pointer
    end

    def llvm_self_ptr
      llvm_self
    end

    def llvm_nil
      int1(0)
    end

    def int1(n)
      LLVM.int LLVM::Int1, n
    end

    def int8(n)
      LLVM.int LLVM::Int8, n
    end

    def int16(n)
      LLVM.int LLVM::Int16, n
    end

    def int32(n)
      LLVM.int LLVM::Int32, n
    end

    def int64(n)
      LLVM.int LLVM::Int64, n
    end

    def accept(node)
      # old_current_node = @current_node
      node.accept self
      # @current_node = old_current_node
    end

    def ret(value)
      # if @needs_gc
      #   @builder.call set_root_index_fun, @gc_root_index
      # end

      @builder.ret value
    end
  end
end

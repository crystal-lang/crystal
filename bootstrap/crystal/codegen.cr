require "parser"
require "type_inference"
require "visitor"
require "llvm"
require "codegen/*"
require "program"

LLVM.init_x86

module Crystal
  DUMP_LLVM = ENV["DUMP"] == "1"

  class Program
    def run(code)
      node = Parser.parse(code)
      node = infer_type node
      evaluate node
    end

    def evaluate(node)
      llvm_mod = build node
      engine = LLVM::JITCompiler.new(llvm_mod)
      engine.run_function llvm_mod.functions["crystal_main"] #, 0, nil
    end

    def build(node)
      visitor = CodeGenVisitor.new(self, node)
      begin
        node.accept visitor
      rescue ex
        visitor.llvm_mod.dump
        raise ex
      end
      visitor.finish
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

    def initialize(@mod, @node)
      @llvm_mod = LLVM::Module.new("Crystal")
      @llvm_typer = LLVMTyper.new
      if node_type = node.type
        ret_type = @llvm_typer.llvm_type(node_type)
      else
        ret_type = LLVM::Void
      end
      @fun = @llvm_mod.functions.add("crystal_main", [] of LLVM::Type, ret_type)
      @builder = LLVM::Builder.new
      @alloca_block, @const_block, @entry_block = new_entry_block_chain ["alloca", "const", "entry"]
      @const_block_entry = @const_block
      @vars = {} of String => LLVMVar
      @strings = {} of String => LibLLVM::ValueRef
      @type = @mod
      @last = int1(0)
    end

    def finish
      br_block_chain [@alloca_block, @const_block_entry]
      br_block_chain [@const_block, @entry_block]
      last = @last
      last.is_a?(LibLLVM::ValueRef) ? @builder.ret(last) : @builder.ret

      @fun = @llvm_mod.functions.add "main", ([] of LLVM::Type), LLVM::Int32
      entry = new_block "entry"
      @builder.position_at_end entry
      @builder.call @llvm_mod.functions["crystal_main"]
      @builder.ret LLVM::Int32.from_i(0)
    end

    def codegen_primitive(node : PrimitiveBinary, target_def, call_args)
      p1, p2 = call_args
      t1, t2 = target_def.owner, target_def.args[0].type
      @last = codegen_binary_op target_def.name, t1, t2, p1, p2
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
      codegen_binary_op op, t2, t1, p2, p1
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

    def codegen_primitive(node : PrimitiveCast, target_def, call_args)
      p1 = call_args[0]
      from_type, to_type = target_def.owner, target_def.type
      @last = codegen_cast from_type, to_type, p1
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

    def codegen_primitive(node : Allocate, target_def, call_args)
      @last = @builder.malloc llvm_struct_type(node.type)
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : NumberLiteral)
      case node.kind
      when :i8, :u8
        @last = int8(node.value.to_i)
      when :i16, :u16
        @last = LLVM::Int16.from_i(node.value.to_i)
      when :i32, :u32
        @last = LLVM::Int32.from_i(node.value.to_i)
      when :i64, :u64
        @last = int64(node.value.to_i64)
      when :f32
        @last = LLVM::Float.from_s(node.value)
      when :f64
        @last = LLVM::Double.from_s(node.value)
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

    def build_string_constant(str, name = "str")
      # name = name.gsub('@', '.')
      @strings.fetch_or_assign(str) do
        global = @llvm_mod.globals.add(LLVM::ArrayType.new(LLVM::Int8, str.length + 5), name)
        global.linkage = LibLLVM::Linkage::Private
        global.global_constant = true

        # Pack the string bytes
        bytes = [] of LibLLVM::ValueRef
        length = str.length
        length_ptr = length.ptr.as(UInt8)
        (0..3).each { |i| bytes << int8(length_ptr[i]) }
        str.each_char { |c| bytes << int8(c.ord) }
        bytes << int8(0)

        global.initializer = LLVM::Value.const_array(LLVM::Int8, bytes)
        cast_to global.value, @mod.string
      end
    end

    def cast_to(value, type)
      @builder.bit_cast(value, llvm_type(type))
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
      @builder.cond(codegen_cond(node_cond), then_block, else_block)

      nil
    end

    def codegen_cond(node_cond)
      # if @mod.nil.equal?(node_cond.type)
      #   cond = int1(0)
      # elsif @mod.bool.equal?(node_cond.type)
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
      # else
      #   cond = int1(1)
      # end
    end

    abstract class BranchedBlock
      property node
      property count
      property exit_block

      def initialize(@node, @exit_block)
        @count = 0
      end
    end

    class UnionBranchedBlock < BranchedBlock
      def initialize(node, exit_block)
        super
        # @union_ptr = alloca llvm_type(node.type)
      end

      def add_value(block, type, value)
        # assign_to_union(branch[:union_ptr], branch[:node].type, type, value)
        @count += 1
      end

      def close(builder, typer)
        # branch[:union_ptr]
        LLVM::Int1.from_i 0
      end
    end

    class PhiBranchedBlock < BranchedBlock
      def initialize(node, exit_block)
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

      def close(builder, typer)
        # if branch[:count] == 0
        #   @builder.unreachable
        # elsif branch[:phi_table].empty?
        #   # All branches are void or no return
        #   @last = llvm_nil
        # else
        builder.phi typer.llvm_type(@node.type), @incoming_blocks, @incoming_values
      end
    end

    def new_branched_block(node)
      exit_block = new_block("exit")
      node_type = node.type
      if node_type && node_type.union?
        UnionBranchedBlock.new node, exit_block
      else
        PhiBranchedBlock.new node, exit_block
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
        @last = branch.close(@builder, @llvm_typer)
      end
    end

    def visit(node : Assign)
      codegen_assign_node(node.target, node.value)
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

    def codegen_assign_node(target, value)
      if target.is_a?(Ident)
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

    def codegen_assign_target(target, value, llvm_value)
      case target
      # when InstanceVar
      #   ivar = @type.lookup_instance_var(target.name.to_s)
      #   ptr = gep llvm_self_ptr, 0, @type.index_of_instance_var(target.name.to_s)
      # when Global
      #   ptr = assign_to_global target.name.to_s, target.type
      # when ClassVar
      #   ptr = assign_to_global class_var_global_name(target), target.type
      # else
      when Var
        var = declare_var(target)
        ptr = var.pointer
        codegen_assign(ptr, target.type, value.type, llvm_value)
      else
        raise "Unknown assign target type: #{target}"
      end

      # codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign(pointer, target_type, value_type, value, instance_var = false)
      if target_type == value_type
        # value = @builder.load value if target_type.union? || (instance_var && (target_type.c_struct? || target_type.c_union?))
        @builder.store value, pointer
      else
        raise "Not implemented: assign_to_union"
        # assign_to_union(pointer, target_type, value_type, value)
      end
    end

    def declare_var(var)
      @vars.fetch_or_assign(var.name.to_s) do
        llvm_var = LLVMVar.new(alloca(llvm_type(var.type), var.name.to_s), var.type)
        # if var.type.is_a?(UnionType) && union_type_id = var.type.types.any?(&:nil_type?)
        #   in_alloca_block { assign_to_union(llvm_var[:ptr], var.type, @mod.nil, llvm_nil) }
        # end
        llvm_var
      end
    end

    def visit(node : Def)
      false
    end

    def visit(node : Ident)
      @last = int64(node.type.not_nil!.instance_type.type_id)
    end

    def visit(node : Call)
      owner = node.target_def.owner

      call_args = [] of LibLLVM::ValueRef

      if (obj = node.obj) && obj.type.try!(&.passed_as_self?)
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
        codegen_primitive(body, target_def, call_args)
        return
      end

      mangled_name = target_def.mangled_name(self_type)

      func = @llvm_mod.functions[mangled_name]? || codegen_fun(mangled_name, target_def, self_type)

      @last = @builder.call func, call_args
    end

    def codegen_fun(mangled_name, target_def, self_type)
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

      @fun = @llvm_mod.functions.add(
        mangled_name,
        args.map { |arg| llvm_arg_type(arg.type) },
        llvm_return_type#,
        # varargs: varargs
      )

      is_external = target_def.is_a?(External)

      unless is_external
        @fun.linkage = LibLLVM::Linkage::Internal
      end

      # args.each_with_index do |arg, i|
      #   @fun.params[i].name = arg.name
      #   # @fun.params[i].add_attribute :by_val_attribute if arg.type.passed_by_val?
      # end

      if !is_external && (body = target_def.body)
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
          accept(body)

          ret(@last)
        end

        br_from_alloca_to_entry

        @builder.position_at_end old_position
      end

      @last = int1(0)

      the_fun = @fun

      @vars = old_vars
      @fun = old_fun
      @entry_block = old_entry_block
      @alloca_block = old_alloca_block
      @type = old_type

      the_fun
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

    def llvm_type(type)
      @llvm_typer.llvm_type(type)
    end

    def llvm_struct_type(type)
      @llvm_typer.llvm_struct_type(type)
    end

    def llvm_arg_type(type)
      @llvm_typer.llvm_arg_type(type)
    end

    def llvm_self
      @fun.get_param(0)
      # @vars["self"].pointer
    end

    def llvm_nil
      int1(0)
    end

    def int1(n)
      LLVM::Int1.from_i n
    end

    def int8(n)
      LLVM::Int8.from_i n
    end

    def int64(n)
      LLVM::Int64.from_i n
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
